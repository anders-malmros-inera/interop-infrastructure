package se.diggsweden.admin.controller;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.http.MediaType;
import org.springframework.test.web.reactive.server.FluxExchangeResult;
import org.springframework.test.web.reactive.server.WebTestClient;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.time.Duration;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class RunnerControllerIntegrationTest {

    @Autowired
    private WebTestClient webClient;

    @Autowired
    private RunnerController controller;

    @Test
    void streamReceivesStateAndLogs() throws Exception {
        // subscribe to /stream
        FluxExchangeResult<String> result = webClient.get()
                .uri("/stream")
                .accept(MediaType.TEXT_EVENT_STREAM)
                .exchange()
                .returnResult(String.class);

        // use reflection to trigger events on controller
        Method m = RunnerController.class.getDeclaredMethod("sendEventToAll", String.class, String.class);
        m.setAccessible(true);
        m.invoke(controller, "state", "started");
        m.invoke(controller, "log", "line1");
        m.invoke(controller, "state", "finished");

        // collect a few emitted items
        List<String> events = result.getResponseBody()
                .take(10)
                .collectList()
                .block(Duration.ofSeconds(5));

        assertThat(events).isNotEmpty();
        // Expect at least state and log content somewhere
        boolean sawState = events.stream().anyMatch(s -> s.contains("state") || s.contains("started") || s.contains("finished"));
        boolean sawLog = events.stream().anyMatch(s -> s.contains("line1") || s.contains("log"));
        assertThat(sawState).isTrue();
        assertThat(sawLog).isTrue();
    }
}
