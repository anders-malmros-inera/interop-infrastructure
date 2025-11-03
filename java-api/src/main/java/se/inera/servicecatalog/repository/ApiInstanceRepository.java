package se.inera.servicecatalog.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import se.inera.servicecatalog.model.ApiInstance;

import java.util.List;

public interface ApiInstanceRepository extends JpaRepository<ApiInstance, String> {
    List<ApiInstance> findByLogicalAddressAndInteroperabilitySpecificationId(String logicalAddress, String interoperabilitySpecificationId);
    List<ApiInstance> findByLogicalAddressAndInteroperabilitySpecificationIdAndStatus(String logicalAddress, String interoperabilitySpecificationId, String status);

    @Query(value = "SELECT * FROM api_instances WHERE (:updatedSince IS NULL OR updated_at > :updatedSince) "
            + "AND (:organizationId IS NULL OR organization_id = :organizationId) "
            + "AND (:interopSpecId IS NULL OR interoperability_specification_id = :interopSpecId)", nativeQuery = true)
    List<ApiInstance> findByOptionalFilters(@Param("updatedSince") java.time.OffsetDateTime updatedSince,
                                            @Param("organizationId") String organizationId,
                                            @Param("interopSpecId") String interoperabilitySpecificationId);
}
