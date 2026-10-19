#!/usr/bin/env bash
# The machine run of porelo_host: a throwaway Ubuntu 26.04 VM on this machine's libvirt stands in
# for a rented host, and `porelo-host up`, the stop, the resume and `down` run against it with the
# stand-in collection. Everything of the run is removed at the end, after a failure too.
#
#   tool/vm-run.sh IMAGE SHA256SUMS [COLLECTION]
#
# IMAGE is Ubuntu 26.04's server cloud image, SHA256SUMS the release's list it is checked against.
# COLLECTION, when given, is porelo-host's own tarball in place of the stand-in. Its plays have no
# stop yet, so `up` must end 0 with their lines relayed; the account Porelo's setup makes is made by
# cloud-init in its place, as porelo-host's own test VM does.
set -euo pipefail

image="$1"
sums="$2"
collection="${3:-}"
connect=qemu:///system
pool=images
here="$(cd "$(dirname "$0")/.." && pwd)"
run="porelo-frontend-host-$(date -u +%Y%m%d%H%M%S)"
work="$(mktemp -d)"
virsh() { command virsh -q -c "$connect" "$@"; }

# **The image is the one Ubuntu lists**, by its own digest, or nothing starts.
digest="$(sha256sum "$image" | cut -c1-64)"
grep -q "^$digest \*ubuntu-26.04-server-cloudimg-amd64.img\$" "$sums" || {
    echo "vm-run: $image is not the server cloud image $sums lists" >&2
    exit 1
}
base="porelo-frontend-host-base-${digest:0:12}.qcow2"

# Anything of an earlier run left standing is refused, never taken over.
if virsh list --all --name | grep -q '^porelo-frontend-host-'; then
    echo "vm-run: a domain porelo-frontend-host-* is there already; nothing started" >&2
    exit 1
fi
if virsh vol-list "$pool" | awk '{print $1}' | grep '^porelo-frontend-host-' | grep -qv "^$base\$"; then
    echo "vm-run: a volume porelo-frontend-host-* is there already; nothing started" >&2
    exit 1
fi

clean() {
    status=$?
    if [ "$status" -ne 0 ] && virsh pool-refresh "$pool" >/dev/null 2>&1 &&
        virsh vol-download "$run-console.log" "$work/console.log" --pool "$pool" >/dev/null 2>&1; then
        echo "vm-run: the last of $run's console:" >&2
        tail -n 60 "$work/console.log" | tr -d '\r' >&2
    fi
    virsh destroy "$run" >/dev/null 2>&1 || true
    virsh undefine "$run" --nvram >/dev/null 2>&1 || virsh undefine "$run" >/dev/null 2>&1 || true
    virsh vol-delete "$run.qcow2" --pool "$pool" >/dev/null 2>&1 || true
    virsh vol-delete "$run-seed.iso" --pool "$pool" >/dev/null 2>&1 || true
    virsh pool-refresh "$pool" >/dev/null 2>&1 || true
    virsh vol-delete "$run-console.log" --pool "$pool" >/dev/null 2>&1 || true
    rm -rf "$work"
    # Believed only once libvirt lists nothing of the run.
    if virsh list --all --name | grep -q "^$run\$" || virsh vol-list "$pool" | grep -q "$run"; then
        echo "vm-run: $run is still there after the clean-up" >&2
        status=1
    else
        echo "vm-run: nothing of $run is left" >&2
    fi
    exit "$status"
}
trap clean EXIT

# The base volume, made once from the checked image and kept, by its digest.
if ! virsh vol-info "$base" --pool "$pool" >/dev/null 2>&1; then
    size="$(qemu-img info --output=json "$image" | python3 -I -c 'import json,sys; print(json.load(sys.stdin)["virtual-size"])')"
    virsh vol-create-as "$pool" "$base" "$size" --format qcow2 >/dev/null
    virsh vol-upload "$base" "$image" --pool "$pool"
fi
virsh vol-create-as "$pool" "$run.qcow2" 20G --format qcow2 --backing-vol "$base" --backing-vol-format qcow2 >/dev/null

# The run's own keys: the person's login, and the host key the "provider" made and so reports.
ssh-keygen -q -t ed25519 -N '' -C "$run" -f "$work/login"
ssh-keygen -q -t ed25519 -N '' -C "$run" -f "$work/host"
mkdir "$work/seed"
cat >"$work/seed/meta-data" <<META
instance-id: $run
local-hostname: $run
META
{
    echo '#cloud-config'
    echo 'ssh_deletekeys: true'
    echo 'ssh_genkeytypes: [ed25519]'
    echo 'ssh_keys:'
    echo '  ed25519_private: |'
    sed 's/^/    /' "$work/host"
    echo "  ed25519_public: $(cat "$work/host.pub")"
    echo 'users:'
    echo '  - name: ubuntu'
    echo '    sudo: ALL=(ALL) NOPASSWD:ALL'
    echo '    shell: /bin/bash'
    echo "    ssh_authorized_keys: [\"$(cat "$work/login.pub")\"]"
    if [ -n "$collection" ]; then
        echo '  - name: porelo'
        echo '    shell: /bin/bash'
        echo 'runcmd:'
        echo '  - [loginctl, enable-linger, porelo]'
    fi
} >"$work/seed/user-data"
xorriso -as genisoimage -quiet -output "$work/seed.iso" -volid cidata -joliet -rock "$work/seed/user-data" "$work/seed/meta-data" 2>/dev/null
virsh vol-create-as "$pool" "$run-seed.iso" "$(stat -c %s "$work/seed.iso")" --format raw >/dev/null
virsh vol-upload "$run-seed.iso" "$work/seed.iso" --pool "$pool"

virt-install --connect "$connect" --name "$run" --memory 2048 --vcpus 2 --import \
    --disk "vol=$pool/$run.qcow2,bus=virtio" --disk "vol=$pool/$run-seed.iso,device=cdrom" \
    --network network=default --osinfo linux2024 --cpu host-passthrough --graphics none --noautoconsole --quiet \
    --serial "file,path=/var/lib/libvirt/images/$run-console.log"

address=''
for _ in $(seq 1 60); do
    address="$(virsh domifaddr "$run" | awk '/ipv4/ {split($4, a, "/"); print a[1]; exit}')"
    [ -n "$address" ] && break
    sleep 2
done
[ -n "$address" ] || {
    echo "vm-run: $run got no address" >&2
    exit 1
}
echo "vm-run: $run at $address" >&2

# The stand-in collection as `ansible-galaxy collection build` lays it out: MANIFEST.json and
# FILES.json at the root, each file with its SHA-256.
tarball="${collection:-$work/porelo-host-0.0.1.tar.gz}"
[ -n "$collection" ] || python3 -I - "$here/test/stub_collection" "$work/collection" <<'PY'
import hashlib, json, os, shutil, sys
source, target = sys.argv[1], sys.argv[2]
shutil.copytree(source, target)
files = [{"name": ".", "ftype": "dir", "chksum_type": None, "chksum_sha256": None, "format": 1}]
for root, dirs, names in os.walk(target):
    dirs.sort()
    for d in dirs:
        files.append({"name": os.path.relpath(os.path.join(root, d), target), "ftype": "dir",
                      "chksum_type": None, "chksum_sha256": None, "format": 1})
    for n in sorted(names):
        path = os.path.join(root, n)
        rel = os.path.relpath(path, target)
        if rel == "galaxy.yml":
            continue
        files.append({"name": rel, "ftype": "file", "chksum_type": "sha256",
                      "chksum_sha256": hashlib.sha256(open(path, "rb").read()).hexdigest(), "format": 1})
os.remove(os.path.join(target, "galaxy.yml"))
listing = json.dumps({"files": files, "format": 1}, indent=4).encode()
open(os.path.join(target, "FILES.json"), "wb").write(listing)
manifest = {"collection_info": {"namespace": "porelo", "name": "host", "version": "0.0.1", "authors": ["porelo-frontend"],
            "readme": "README.md", "tags": [], "description": None, "license": ["Apache-2.0"], "license_file": None,
            "dependencies": {}, "repository": None, "documentation": None, "homepage": None, "issues": None},
            "file_manifest_file": {"name": "FILES.json", "ftype": "file", "chksum_type": "sha256",
                                   "chksum_sha256": hashlib.sha256(listing).hexdigest(), "format": 1},
            "format": 1}
open(os.path.join(target, "MANIFEST.json"), "w").write(json.dumps(manifest, indent=4))
PY
[ -n "$collection" ] || (cd "$work/collection" && tar -czf "$tarball" MANIFEST.json FILES.json README.md meta playbooks plugins)

hostkey="$(cut -d' ' -f1,2 "$work/host.pub")"
host() {
    dart run "$here/bin/porelo_host.dart" "$@" --project demo --account porelo --public-key "$work/login.pub" \
        --identity "$work/login" --collection "$tarball" --given "$address" --host-key "$hostkey"
}
expect() {
    local want="$1" got="$2" what="$3"
    [ "$want" = "$got" ] || {
        echo "vm-run: $what ended with $got, not $want" >&2
        exit 1
    }
    echo "vm-run: $what ended with $got, as it must" >&2
}

set +e
# **A host key other than the provider's is refused before anything logs in.**
ssh-keygen -q -t ed25519 -N '' -f "$work/other"
right="$hostkey"
hostkey="$(cut -d' ' -f1,2 "$work/other.pub")"
host up >"$work/up-0.jsonl"
refused=$?
hostkey="$right"
expect 69 "$refused" 'an up told another host key'
grep -q '"step":"copy"' "$work/up-0.jsonl" && {
    echo 'vm-run: it went on past ssh' >&2
    exit 1
}

if [ -n "$collection" ]; then
    # The real plays stop for the drive's login, which nobody gives here: the stop is the end.
    host up --tresor porelo-host-test >"$work/up-1.jsonl"
    expect 75 "$?" "the first up against $(basename "$collection")"
    grep -q '"step":"person","state":"waiting","needs":\["drive"\]' "$work/up-1.jsonl" || {
        echo 'vm-run: no waiting line asking for the drive alone' >&2
        exit 1
    }
    grep -q '"state":"done"' "$work/up-1.jsonl" || {
        echo "vm-run: no task of the plays was relayed" >&2
        exit 1
    }
    host down --tresor porelo-host-test >"$work/down.jsonl"
    echo "vm-run: down after the stop ended with $?" >&2
    set -e
    cat "$work"/up-1.jsonl "$work"/down.jsonl
    exit 0
fi

host up >"$work/up-1.jsonl"
first=$?
expect 75 "$first" 'the first up'
grep -q '"state":"waiting"' "$work/up-1.jsonl" || {
    echo 'vm-run: no waiting line' >&2
    exit 1
}

echo '{"driveEmail": "me@example.org", "drivePassword": "wrong-is-fine-here", "vaultPassphrase": "x"}' |
    host up --answers-on-stdin >"$work/up-2.jsonl"
second=$?
expect 0 "$second" 'the second up, given the answers'
grep -q '"step":"rent","state":"done"' "$work/up-2.jsonl"

# Nothing of an answer is in any file the run wrote on the host. The same search must find the
# inventory's account name, so a search that saw nothing cannot pass for one that found nothing.
search() {
    printf '%s\n' "$(cut -d' ' -f1,2 "$work/host.pub")" | sed "s/^/$address /" >"$work/known_hosts"
    ssh -o BatchMode=yes -o IdentitiesOnly=yes -o UserKnownHostsFile="$work/known_hosts" -i "$work/login" \
        "ubuntu@$address" 'sudo grep -rlFf - /var/tmp/porelo-host /home /var/log /tmp; true' <<<"$1"
}
# The word searched for goes on the search's standard input: in its command line, sudo's own log
# would hold it, and the search would find itself.
seen="$(search porelo_host_account)" || {
    echo 'vm-run: the search could not log in' >&2
    exit 1
}
[ -n "$seen" ] || {
    echo 'vm-run: the search found not even the inventory' >&2
    exit 1
}
leaked="$(search wrong-is-fine-here)" || {
    echo 'vm-run: the search could not log in' >&2
    exit 1
}
[ -z "$leaked" ] || {
    echo "vm-run: an answer was written to $leaked" >&2
    exit 1
}
echo "vm-run: no answer in any file on the host; the same search found $(echo "$seen" | head -1)" >&2

host down >"$work/down.jsonl"
down=$?
expect 0 "$down" 'down'
set -e
cat "$work"/up-1.jsonl "$work"/up-2.jsonl "$work"/down.jsonl
