package se.diggsweden.catalog.service;

import org.springframework.stereotype.Service;
import se.diggsweden.catalog.dto.ServiceEntryDto;
import se.diggsweden.catalog.model.ServiceEntry;
import se.diggsweden.catalog.repository.ServiceEntryRepository;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.Collectors;
import se.diggsweden.catalog.model.ServiceEndpoint;
import se.diggsweden.catalog.dto.ServiceEndpointDto;
import se.diggsweden.catalog.repository.ServiceEndpointRepository;
import se.diggsweden.catalog.dto.ContactDto;

@Service
public class ServiceEntryService {

    private final ServiceEntryRepository repository;
    private final ServiceEndpointRepository endpointRepository;

    // constructor used by Spring for injection
    @org.springframework.beans.factory.annotation.Autowired
    public ServiceEntryService(ServiceEntryRepository repository, ServiceEndpointRepository endpointRepository) {
        this.repository = repository;
        this.endpointRepository = endpointRepository;
    }

    public ServiceEntryDto create(ServiceEntryDto dto) {
        ServiceEntry e = toEntity(dto);
        e.setCreatedAt(OffsetDateTime.now());
        e.setUpdatedAt(OffsetDateTime.now());
        ServiceEntry saved = repository.save(e);
        return toDto(saved);
    }

    public Optional<ServiceEntryDto> get(UUID id) {
        return repository.findById(id).map(this::toDto);
    }

    public List<ServiceEntryDto> list() {
        return repository.findAll().stream().map(this::toDto).collect(Collectors.toList());
    }

    public Optional<ServiceEntryDto> update(UUID id, ServiceEntryDto dto) {
        return repository.findById(id).map(existing -> {
            existing.setName(dto.getName());
            existing.setServiceCode(dto.getServiceCode());
            existing.setVersion(dto.getVersion());
            existing.setDescription(dto.getDescription());
            existing.setOwner(dto.getOwner());
            // map contactInfo -> Contact embeddable
            if (dto.getContactInfo() != null) {
                se.diggsweden.catalog.model.Contact c = new se.diggsweden.catalog.model.Contact();
                c.setContactName(dto.getContactInfo().getContactName());
                c.setContactEmail(dto.getContactInfo().getContactEmail());
                c.setContactPhone(dto.getContactInfo().getContactPhone());
                existing.setContact(c);
            } else {
                existing.setContact(null);
            }
            existing.setTags(dto.getTags());
            existing.setStatus(dto.getStatus());
            existing.setClassification(dto.getClassification());
            existing.setDocumentationUrl(dto.getDocumentationUrl());
            existing.setSla(dto.getSla());
            existing.setUpdatedAt(OffsetDateTime.now());
            return toDto(repository.save(existing));
        });
    }

    public void delete(UUID id) {
        repository.deleteById(id);
    }

    private ServiceEntry toEntity(ServiceEntryDto dto) {
        ServiceEntry e = new ServiceEntry();
        e.setServiceCode(dto.getServiceCode());
        e.setName(dto.getName());
        e.setVersion(dto.getVersion());
        e.setDescription(dto.getDescription());
        e.setOwner(dto.getOwner());
        // contact mapping (simple)
        if (dto.getContactInfo() != null) {
            se.diggsweden.catalog.model.Contact c = new se.diggsweden.catalog.model.Contact();
            c.setContactName(dto.getContactInfo().getContactName());
            c.setContactEmail(dto.getContactInfo().getContactEmail());
            c.setContactPhone(dto.getContactInfo().getContactPhone());
            e.setContact(c);
        }
        e.setTags(dto.getTags());
        e.setStatus(dto.getStatus());
        e.setClassification(dto.getClassification());
        e.setDocumentationUrl(dto.getDocumentationUrl());
        e.setSla(dto.getSla());
        return e;
    }

    private ServiceEntryDto toDto(ServiceEntry e) {
        ServiceEntryDto d = new ServiceEntryDto();
        d.setId(e.getId());
        d.setServiceCode(e.getServiceCode());
        d.setName(e.getName());
        d.setVersion(e.getVersion());
        d.setDescription(e.getDescription());
        d.setOwner(e.getOwner());
        if (e.getContact() != null) {
            ContactDto cd = new ContactDto();
            cd.setContactName(e.getContact().getContactName());
            cd.setContactEmail(e.getContact().getContactEmail());
            cd.setContactPhone(e.getContact().getContactPhone());
            d.setContactInfo(cd);
        }
        d.setTags(e.getTags());
        d.setStatus(e.getStatus());
        d.setClassification(e.getClassification());
        d.setDocumentationUrl(e.getDocumentationUrl());
        d.setSla(e.getSla());
        if (e.getEndpoints() != null) {
            d.setEndpoints(e.getEndpoints().stream().map(ep -> {
                ServiceEndpointDto dto = new ServiceEndpointDto();
                dto.setId(ep.getId());
                dto.setName(ep.getName());
                dto.setType(ep.getType() != null ? ep.getType().name() : null);
                dto.setUrl(ep.getUrl());
                dto.setVersion(ep.getVersion());
                dto.setSecurity(ep.getSecurity() != null ? ep.getSecurity().name() : null);
                dto.setDescription(ep.getDescription());
                return dto;
            }).collect(Collectors.toList()));
        }
        return d;
    }

    public ServiceEndpointDto createEndpoint(UUID serviceId, ServiceEndpointDto dto) {
        ServiceEndpoint e = new ServiceEndpoint();
        e.setName(dto.getName());
        if (dto.getType() != null) e.setType(ServiceEndpoint.EndpointType.valueOf(dto.getType()));
        e.setUrl(dto.getUrl());
        e.setVersion(dto.getVersion());
        if (dto.getSecurity() != null) e.setSecurity(ServiceEndpoint.SecurityType.valueOf(dto.getSecurity()));
        e.setDescription(dto.getDescription());
        ServiceEntry parent = repository.findById(serviceId).orElseThrow(() -> new IllegalArgumentException("Service not found"));
        e.setServiceEntry(parent);
        ServiceEndpoint saved = endpointRepository.save(e);
        ServiceEndpointDto out = new ServiceEndpointDto();
        out.setId(saved.getId());
        out.setName(saved.getName());
        out.setType(saved.getType() != null ? saved.getType().name() : null);
        out.setUrl(saved.getUrl());
        out.setVersion(saved.getVersion());
        out.setSecurity(saved.getSecurity() != null ? saved.getSecurity().name() : null);
        out.setDescription(saved.getDescription());
        return out;
    }

    public void deleteEndpoint(UUID endpointId) {
        endpointRepository.deleteById(endpointId);
    }
}