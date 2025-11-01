package se.inera.servicecatalog.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.OffsetDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Map;

@RestController
public class PingController {

    @GetMapping("/_ping")
    public Map<String, Object> ping() {
        String now = OffsetDateTime.now().format(DateTimeFormatter.ISO_OFFSET_DATE_TIME);
        return Map.of(
                "ok", 1,
                "now", now
        );
    }
}
