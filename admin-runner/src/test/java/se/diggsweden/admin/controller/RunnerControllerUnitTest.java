package se.diggsweden.admin.controller;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.io.IOException;
import java.lang.reflect.Field;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

class RunnerControllerUnitTest {

    private RunnerController controller;

    @BeforeEach
    void setUp() {
        controller = new RunnerController();
    }

    @Test
    void sendEventToAll_removesEmittersThatFailOnSend() throws Exception {
        // create a broken emitter that throws on send
        SseEmitter broken = new SseEmitter() {
            @Override
            public void send(Object object) throws IOException {
                throw new IOException("send failed");
            }
        };

        // add it to the controller.emitters via reflection
        Field f = RunnerController.class.getDeclaredField("emitters");
        f.setAccessible(true);
        @SuppressWarnings("unchecked")
        List<SseEmitter> list = (List<SseEmitter>) f.get(controller);
        list.add(broken);

        // invoke sendEventToAll via reflection
        java.lang.reflect.Method m = RunnerController.class.getDeclaredMethod("sendEventToAll", String.class, String.class);
        m.setAccessible(true);

        // should not throw; broken emitter should be removed
        m.invoke(controller, "log", "hello");

        // verify the emitter was removed from the internal list
        assertThat(list).doesNotContain(broken);
    }
}
package se.diggsweden.admin.controller;

import org.junit.jupiter.api.Test;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.io.IOException;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class RunnerControllerUnitTest {

    @Test
    void whenEmitterSendFails_itIsRemoved() throws Exception {
        RunnerController controller = new RunnerController();

        // create a mock emitter that throws on send
    SseEmitter emitter = mock(SseEmitter.class);
    // disambiguate overloaded send(...) by specifying the SseEventBuilder variant
    doThrow(new IOException("broken")).when(emitter).send(any(org.springframework.web.servlet.mvc.method.annotation.SseEmitter.SseEventBuilder.class));

        // inject emitter into private emitters list
        Field f = RunnerController.class.getDeclaredField("emitters");
        f.setAccessible(true);
        @SuppressWarnings("unchecked")
        List<SseEmitter> emitters = (List<SseEmitter>) f.get(controller);
        emitters.add(emitter);

        // call private sendEventToAll via reflection
        Method m = RunnerController.class.getDeclaredMethod("sendEventToAll", String.class, String.class);
        m.setAccessible(true);
        m.invoke(controller, "log", "some data");

        // emitter should have been removed after send failure
        assertFalse(emitters.contains(emitter));
    }
}
