package se.inera.servicecatalog.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import se.inera.servicecatalog.model.ApiInstance;
import se.inera.servicecatalog.repository.ApiInstanceRepository;

import java.time.OffsetDateTime;
import java.util.List;
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
        return ResponseEntity.status(201).body(instance.getId());
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
        // Simple implementation: filter in-memory for optional params
        List<ApiInstance> all = repo.findAll();
        return ResponseEntity.ok(all.stream().filter(a -> {
            if (updatedSince != null && a.getUpdatedAt() != null && a.getUpdatedAt().isBefore(updatedSince)) return false;
            if (organizationId != null && (a.getOrganizationId() == null || !a.getOrganizationId().equals(organizationId))) return false;
            if (interoperabilitySpecificationId != null && (a.getInteroperabilitySpecificationId() == null || !a.getInteroperabilitySpecificationId().equals(interoperabilitySpecificationId))) return false;
            return true;
        }).toList());
    }
}
