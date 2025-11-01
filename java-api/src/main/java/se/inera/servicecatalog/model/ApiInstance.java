package se.inera.servicecatalog.model;

import javax.persistence.Column;
import javax.persistence.Entity;
import javax.persistence.Id;
import javax.persistence.Table;
import java.time.OffsetDateTime;

@Entity
@Table(name = "api_instances")
public class ApiInstance {
    @Id
    @Column(name = "id")
    private String id;

    @Column(name = "logical_address")
    private String logicalAddress;

    @Column(name = "organization_id")
    private String organizationId;

    @Column(name = "organization_name")
    private String organizationName;

    @Column(name = "interoperability_specification_id")
    private String interoperabilitySpecificationId;

    @Column(name = "api_standard")
    private String apiStandard;

    @Column(name = "url")
    private String url;

    @Column(name = "status")
    private String status;

    @Column(name = "access_model_type")
    private String accessModelType;

    @Column(name = "access_model_metadata_url")
    private String accessModelMetadataUrl;

    @Column(name = "signature")
    private String signature;

    @Column(name = "created_at")
    private OffsetDateTime createdAt;

    @Column(name = "updated_at")
    private OffsetDateTime updatedAt;

    // Getters and setters (omitted for brevity in this patch - generated)

    public String getId() { return id; }
    public void setId(String id) { this.id = id; }
    public String getLogicalAddress() { return logicalAddress; }
    public void setLogicalAddress(String logicalAddress) { this.logicalAddress = logicalAddress; }
    public String getOrganizationId() { return organizationId; }
    public void setOrganizationId(String organizationId) { this.organizationId = organizationId; }
    public String getOrganizationName() { return organizationName; }
    public void setOrganizationName(String organizationName) { this.organizationName = organizationName; }
    public String getInteroperabilitySpecificationId() { return interoperabilitySpecificationId; }
    public void setInteroperabilitySpecificationId(String interoperabilitySpecificationId) { this.interoperabilitySpecificationId = interoperabilitySpecificationId; }
    public String getApiStandard() { return apiStandard; }
    public void setApiStandard(String apiStandard) { this.apiStandard = apiStandard; }
    public String getUrl() { return url; }
    public void setUrl(String url) { this.url = url; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    public String getAccessModelType() { return accessModelType; }
    public void setAccessModelType(String accessModelType) { this.accessModelType = accessModelType; }
    public String getAccessModelMetadataUrl() { return accessModelMetadataUrl; }
    public void setAccessModelMetadataUrl(String accessModelMetadataUrl) { this.accessModelMetadataUrl = accessModelMetadataUrl; }
    public String getSignature() { return signature; }
    public void setSignature(String signature) { this.signature = signature; }
    public OffsetDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(OffsetDateTime createdAt) { this.createdAt = createdAt; }
    public OffsetDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(OffsetDateTime updatedAt) { this.updatedAt = updatedAt; }
}
