package se.diggsweden.catalog.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.util.UUID;

public class ServiceEntryDto {
    private UUID id;

    @NotBlank
    private String name;

    @Size(max = 100)
    private String version;

    @Size(max = 2000)
    private String description;

    private String owner;
    private String contact;
    private String tags;
    private String status;
    private String serviceCode;
    private String provider;
    private String classification;
    private String documentationUrl;
    private String sla;
    private java.util.List<ServiceEndpointDto> endpoints;
    private ContactDto contactInfo;

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

    public String getVersion() {
        return version;
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

    public String getServiceCode() {
        return serviceCode;
    }

    public void setServiceCode(String serviceCode) {
        this.serviceCode = serviceCode;
    }

    public String getProvider() {
        return provider;
    }

    public void setProvider(String provider) {
        this.provider = provider;
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

    public java.util.List<ServiceEndpointDto> getEndpoints() {
        return endpoints;
    }

    public void setEndpoints(java.util.List<ServiceEndpointDto> endpoints) {
        this.endpoints = endpoints;
    }

    public ContactDto getContactInfo() {
        return contactInfo;
    }

    public void setContactInfo(ContactDto contactInfo) {
        this.contactInfo = contactInfo;
    }
}