package org.fuin.porelo.test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

/**
 * Unit test for simple App.
 */
public class AppTest {

    /**
     * Rigorous Test :-)
     */
    @Test
    public void shouldAnswerWithTrue() {
        assertTrue(true);
    }

    /**
     * Counts the words of the greeting.
     */
    @Test
    public void greetingHasTwoWords() {
        assertEquals(3, "Hello World!".split(" ").length);
    }
}
