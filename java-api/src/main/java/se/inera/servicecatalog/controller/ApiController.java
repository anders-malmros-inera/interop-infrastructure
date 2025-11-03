package se.inera.servicecatalog.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import se.inera.servicecatalog.model.ApiInstance;
import se.inera.servicecatalog.repository.ApiInstanceRepository;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.Optional;

@RestController
@RequestMapping("/apis")
public class ApiController {

    @Autowired
    private ApiInstanceRepository repo;

    @GetMapping
    public ResponseEntity<List<ApiInstance>> search(@RequestParam String logicalAddress,
                                                    @RequestParam String interoperabilitySpecificationId,
                                                    @RequestParam(required = false) String status) {
        List<ApiInstance> results;
        if (status != null && !status.isEmpty()) {
            results = repo.findByLogicalAddressAndInteroperabilitySpecificationIdAndStatus(logicalAddress, interoperabilitySpecificationId, status);
        } else {
            results = repo.findByLogicalAddressAndInteroperabilitySpecificationId(logicalAddress, interoperabilitySpecificationId);
        }
        return ResponseEntity.ok(results);
    }

    @PostMapping
    public ResponseEntity<?> create(@RequestBody ApiInstance instance) {
        if (instance.getId() == null) instance.setId(java.util.UUID.randomUUID().toString());
        if (instance.getCreatedAt() == null) instance.setCreatedAt(OffsetDateTime.now());
        instance.setUpdatedAt(OffsetDateTime.now());
        repo.save(instance);
        // Return JSON object with created id to match Perl API behavior
        return ResponseEntity.status(201).body(Map.of("id", instance.getId()));
    }

    @GetMapping("/{id}")
    public ResponseEntity<?> get(@PathVariable String id) {
        Optional<ApiInstance> r = repo.findById(id);
        return r.map(ResponseEntity::ok).orElseGet(() -> ResponseEntity.notFound().build());
    }

    @PutMapping("/{id}")
    public ResponseEntity<?> update(@PathVariable String id, @RequestBody ApiInstance instance) {
        if (!repo.existsById(id)) return ResponseEntity.notFound().build();
        instance.setId(id);
        instance.setUpdatedAt(OffsetDateTime.now());
        repo.save(instance);
        return ResponseEntity.ok().build();
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<?> delete(@PathVariable String id) {
        repo.deleteById(id);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/sync/apis")
    public ResponseEntity<List<ApiInstance>> sync(@RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime updatedSince,
                                                 @RequestParam(required = false) String organizationId,
                                                 @RequestParam(required = false) String interoperabilitySpecificationId) {
        // Delegate filtering to the repository (database) to avoid loading the entire table into memory
        List<ApiInstance> results = repo.findByOptionalFilters(updatedSince, organizationId, interoperabilitySpecificationId);
        return ResponseEntity.ok(results);
    }
}
