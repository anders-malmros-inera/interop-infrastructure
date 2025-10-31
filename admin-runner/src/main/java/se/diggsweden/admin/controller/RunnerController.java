package se.diggsweden.admin.controller;

import org.springframework.http.MediaType;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.ResponseBody;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicBoolean;

@Controller
public class RunnerController {

    private final ExecutorService exec = Executors.newSingleThreadExecutor();
    private final AtomicBoolean running = new AtomicBoolean(false);
    private final List<SseEmitter> emitters = new CopyOnWriteArrayList<>();

    @GetMapping("/")
    public String index() {
        return "index";
    }

    @PostMapping("/run-tests")
    @ResponseBody
    public String runTests() {
        if (running.get()) {
            return "ALREADY_RUNNING";
        }
        running.set(true);
        exec.submit(() -> {
            try {
                // working dir will be /workspace (docker-compose mounts repo here)
                ProcessBuilder pb = new ProcessBuilder()
                        .command("mvn", "-pl", "service-catalog", "-am", "-DskipTests=false", "test")
                        .directory(new java.io.File("/workspace"));
                pb.redirectErrorStream(true);
                Process p = pb.start();
                try (BufferedReader br = new BufferedReader(new InputStreamReader(p.getInputStream(), StandardCharsets.UTF_8))) {
                    String line;
                    // notify clients that run started
                    sendEventToAll("state", "started");
                    while ((line = br.readLine()) != null) {
                        // print to container stdout as well
                        System.out.println(line);
                        // forward to SSE clients
                        sendEventToAll("log", line);
                    }
                    sendEventToAll("state", "finished");
                }
                p.waitFor();
            } catch (Exception e) {
                e.printStackTrace();
                sendEventToAll("error", e.getMessage());
            } finally {
                running.set(false);
            }
        });
        return "OK";
    }

    @GetMapping(path = "/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public SseEmitter stream() {
        SseEmitter emitter = new SseEmitter(Duration.ofHours(1).toMillis());
        // register
        emitters.add(emitter);

        // initial state push
        try {
            emitter.send(SseEmitter.event().name("state").data(running.get() ? "running" : "idle"));
        } catch (Exception ignored) {}

        emitter.onCompletion(() -> emitters.remove(emitter));
        emitter.onTimeout(() -> emitters.remove(emitter));
        emitter.onError((ex) -> emitters.remove(emitter));

        return emitter;
    }

    private void sendEventToAll(String eventName, String data) {
        for (SseEmitter e : emitters) {
            try {
                e.send(SseEmitter.event().name(eventName).data(data));
            } catch (Exception ex) {
                try { e.completeWithError(ex); } catch (Exception ignore) {}
                emitters.remove(e);
            }
        }
    }
}
