package se.diggsweden.admin.controller;

import org.springframework.http.MediaType;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
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
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.logging.Level;
import java.util.logging.Logger;

@Controller
public class RunnerController {

    private final ExecutorService exec = Executors.newSingleThreadExecutor();
    private final AtomicBoolean running = new AtomicBoolean(false);
    private final List<SseEmitter> emitters = new CopyOnWriteArrayList<>();
    private static final Logger LOG = Logger.getLogger(RunnerController.class.getName());
    private final ScheduledExecutorService heartbeat = Executors.newSingleThreadScheduledExecutor();

    public RunnerController() {
        // periodic heartbeat to keep SSE connections alive (helps through proxies)
        heartbeat.scheduleAtFixedRate(() -> {
            try {
                sendEventToAll("ping", "");
            } catch (Exception e) {
                LOG.log(Level.FINE, "Heartbeat send failed", e);
            }
        }, 15, 15, TimeUnit.SECONDS);
    }

    @GetMapping("/")
    public String index() {
        return "index";
    }

    @PostMapping("/run-tests")
    @ResponseBody
    public String runTests(@RequestParam(required = false) String test) {
        if (running.get()) {
            return "ALREADY_RUNNING";
        }
        running.set(true);
        exec.submit(() -> {
            try {
                // working dir will be /workspace (docker-compose mounts repo here)
                // Instead of running mvn inside this container, perform a `docker build` of the
                // `service-catalog` image which executes the tests during the build stage.
                String kc = System.getenv("KEYCLOAK_URL");
                String buildArg = "KEYCLOAK_URL=" + (kc == null ? "" : kc);

                // Run mvn directly inside this container. The admin-runner container has the
                // project mounted at /workspace (compose mounts the repo) and also has the
                // host Docker socket mounted so Testcontainers can start sibling containers.
        // Build the mvn command; add a -Dtest parameter when requested
        java.util.List<String> cmd = new java.util.ArrayList<>();
        cmd.add("mvn");
        cmd.add("-f");
        cmd.add("service-catalog/pom.xml");
        cmd.add("-DskipTests=false");
        if (test != null && !test.isEmpty()) {
            cmd.add("-Dtest=" + test);
        }
        cmd.add("test");

        ProcessBuilder pb = new ProcessBuilder()
            .command(cmd)
            .directory(new java.io.File("/workspace"));
                pb.redirectErrorStream(true);
                // Ensure KEYCLOAK_URL from this container's environment is passed into the Maven process
                if (kc != null && !kc.isEmpty()) {
                    pb.environment().put("KEYCLOAK_URL", kc);
                }

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
                }
                // wait for process exit and then send result
                int exitCode = p.waitFor();
                // send finished state and result (format: <testId>|OK or <testId>|FAIL)
                sendEventToAll("state", "finished");
                String resultId = (test == null || test.isEmpty()) ? "all" : test;
                sendEventToAll("result", resultId + "|" + (exitCode == 0 ? "OK" : "FAIL"));
            } catch (Exception e) {
                e.printStackTrace();
                sendEventToAll("error", e.getMessage());
                String resultId = (test == null || test.isEmpty()) ? "all" : test;
                try { sendEventToAll("result", resultId + "|FAIL"); } catch (Exception ignore) {}
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

        LOG.info("SSE client connected, total clients=" + emitters.size());

        // initial state push
        try {
            emitter.send(SseEmitter.event().name("state").data(running.get() ? "running" : "idle"));
        } catch (Exception e) {
            LOG.log(Level.WARNING, "Failed to send initial state to SSE client", e);
        }

        emitter.onCompletion(() -> {
            emitters.remove(emitter);
            LOG.info("SSE client completed, total clients=" + emitters.size());
        });
        emitter.onTimeout(() -> {
            emitters.remove(emitter);
            LOG.info("SSE client timed out, total clients=" + emitters.size());
        });
        emitter.onError((ex) -> {
            emitters.remove(emitter);
            LOG.log(Level.WARNING, "SSE client error, total clients=" + emitters.size(), ex);
        });

        return emitter;
    }

    private void sendEventToAll(String eventName, String data) {
        for (SseEmitter e : emitters) {
            try {
                // Log the send attempt: keep log events quiet, but state/error/ping as INFO so we can diagnose
                if ("log".equals(eventName)) {
                    LOG.fine(() -> "Sending 'log' event (len=" + (data==null?0:data.length()) + ")");
                } else {
                    LOG.info(() -> "Sending event '" + eventName + "' to emitter " + e + " (data length=" + (data==null?0:data.length()) + ")");
                }
                e.send(SseEmitter.event().name(eventName).data(data));
            } catch (Exception ex) {
                LOG.log(Level.INFO, "Failed sending event '" + eventName + "' to an emitter, removing it", ex);
                try { e.completeWithError(ex); } catch (Exception ignore) {}
                emitters.remove(e);
            }
        }
    }
}

