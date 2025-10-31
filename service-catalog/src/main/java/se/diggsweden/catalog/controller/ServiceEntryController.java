package se.diggsweden.catalog.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;
import se.diggsweden.catalog.dto.ServiceEntryDto;
import se.diggsweden.catalog.dto.ServiceEndpointDto;
import se.diggsweden.catalog.service.ServiceEntryService;

import jakarta.validation.Valid;
import java.net.URI;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/services")
@Validated
public class ServiceEntryController {

    private final ServiceEntryService service;

    public ServiceEntryController(ServiceEntryService service) {
        this.service = service;
    }

    @GetMapping
    @PreAuthorize("hasAuthority('SCOPE_catalog.read')")
    public ResponseEntity<List<ServiceEntryDto>> list() {
        return ResponseEntity.ok(service.list());
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAuthority('SCOPE_catalog.read')")
    public ResponseEntity<ServiceEntryDto> get(@PathVariable UUID id) {
        return service.get(id).map(ResponseEntity::ok).orElseGet(() -> ResponseEntity.notFound().build());
    }

    @PostMapping
    @PreAuthorize("hasAuthority('SCOPE_catalog.write')")
    public ResponseEntity<ServiceEntryDto> create(@Valid @RequestBody ServiceEntryDto dto) {
        ServiceEntryDto created = service.create(dto);
        return ResponseEntity.created(URI.create("/api/v1/services/" + created.getId())).body(created);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAuthority('SCOPE_catalog.write')")
    public ResponseEntity<ServiceEntryDto> update(@PathVariable UUID id, @Valid @RequestBody ServiceEntryDto dto) {
        return service.update(id, dto).map(ResponseEntity::ok).orElseGet(() -> ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAuthority('SCOPE_catalog.admin')")
    public ResponseEntity<Void> delete(@PathVariable UUID id) {
        service.delete(id);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/{id}/endpoints")
    @PreAuthorize("hasAuthority('SCOPE_catalog.write')")
    public ResponseEntity<ServiceEndpointDto> createEndpoint(@PathVariable UUID id, @Valid @RequestBody ServiceEndpointDto dto) {
        ServiceEndpointDto created = service.createEndpoint(id, dto);
        return ResponseEntity.created(URI.create("/api/v1/services/" + id + "/endpoints/" + created.getId())).body(created);
    }

    @DeleteMapping("/{id}/endpoints/{endpointId}")
    @PreAuthorize("hasAuthority('SCOPE_catalog.write')")
    public ResponseEntity<Void> deleteEndpoint(@PathVariable UUID id, @PathVariable UUID endpointId) {
        service.deleteEndpoint(endpointId);
        return ResponseEntity.noContent().build();
    }
}