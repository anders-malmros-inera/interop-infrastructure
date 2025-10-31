package se.diggsweden.catalog.model;

import jakarta.persistence.*;
import java.util.UUID;

@Entity
@Table(name = "service_endpoint")
public class ServiceEndpoint {

    @Id
    @GeneratedValue
    private UUID id;

    private String name;

    @Enumerated(EnumType.STRING)
    private EndpointType type;

    private String url;
    private String version;

    @Enumerated(EnumType.STRING)
    private SecurityType security;

    @Column(length = 2000)
    private String description;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "service_entry_id")
    private ServiceEntry serviceEntry;

    public enum EndpointType { REST, SOAP, GRAPHQL, GRPC, OTHER }
    public enum SecurityType { PUBLIC, OAUTH2, API_KEY, MTLS, OTHER }

    // getters and setters

    public UUID getId() {
        return id;
    }

    public void setId(UUID id) {
        this.id = id;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public EndpointType getType() {
        return type;
    }

    public void setType(EndpointType type) {
        this.type = type;
    }

    public String getUrl() {
        return url;
    }

    public void setUrl(String url) {
        this.url = url;
    }

    public String getVersion() {
        return version;
    }

    public void setVersion(String version) {
        this.version = version;
    }

    public SecurityType getSecurity() {
        return security;
    }

    public void setSecurity(SecurityType security) {
        this.security = security;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public ServiceEntry getServiceEntry() {
        return serviceEntry;
    }

    public void setServiceEntry(ServiceEntry serviceEntry) {
        this.serviceEntry = serviceEntry;
    }
}