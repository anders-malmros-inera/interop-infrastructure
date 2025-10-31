package se.diggsweden.catalog.model;

import jakarta.persistence.*;
import java.time.OffsetDateTime;
import java.util.HashSet;
import java.util.Set;
import java.util.UUID;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.OneToMany;
import jakarta.persistence.CascadeType;
import jakarta.persistence.Embedded;

@Entity
@Table(name = "service_entry")
public class ServiceEntry {

    @Id
    @GeneratedValue
    private UUID id;

    @Column(nullable = false)
    private String name;

    private String version;

    @Column(length = 2000)
    private String description;

    private String owner;

    private String contact;

    private String tags; // comma separated

    @Enumerated(EnumType.STRING)
    private LifecycleStatus lifecycleStatus;

    private String classification;
    private String documentationUrl;
    private String sla;

    private OffsetDateTime createdAt;
    private OffsetDateTime updatedAt;

    @OneToMany(mappedBy = "serviceEntry", cascade = CascadeType.ALL, orphanRemoval = true)
    private Set<ServiceEndpoint> endpoints = new HashSet<>();

    @Embedded
    private Contact contact;

    public enum LifecycleStatus { DRAFT, PUBLISHED, DEPRECATED, RETIRED }

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

    public String getStatus() {
        return lifecycleStatus != null ? lifecycleStatus.name() : null;
    }

    public void setStatus(String status) {
        if (status == null) {
            this.lifecycleStatus = null;
        } else {
            this.lifecycleStatus = LifecycleStatus.valueOf(status);
        }
    }

    public LifecycleStatus getLifecycleStatus() {
        return lifecycleStatus;
    }

    public void setLifecycleStatus(LifecycleStatus lifecycleStatus) {
        this.lifecycleStatus = lifecycleStatus;
    }

    public String getClassification() {
        return classification;
    }

    public void setClassification(String classification) {
        this.classification = classification;
    }

    public String getDocumentationUrl() {
        return documentationUrl;
    }

    public void setDocumentationUrl(String documentationUrl) {
        this.documentationUrl = documentationUrl;
    }

    public String getSla() {
        return sla;
    }

    public void setSla(String sla) {
        this.sla = sla;
    }

    public Set<ServiceEndpoint> getEndpoints() {
        return endpoints;
    }

    public void setEndpoints(Set<ServiceEndpoint> endpoints) {
        this.endpoints = endpoints;
    }

    public Contact getContact() {
        return contact;
    }

    public void setContact(Contact contact) {
        this.contact = contact;
    }

    public void setVersion(String version) {
        this.version = version;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public String getOwner() {
        return owner;
    }

    public void setOwner(String owner) {
        this.owner = owner;
    }

    public String getContact() {
        return contact;
    }

    public void setContact(String contact) {
        this.contact = contact;
    }

    public String getTags() {
        return tags;
    }

    public void setTags(String tags) {
        this.tags = tags;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public OffsetDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(OffsetDateTime createdAt) {
        this.createdAt = createdAt;
    }

    public OffsetDateTime getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(OffsetDateTime updatedAt) {
        this.updatedAt = updatedAt;
    }
}