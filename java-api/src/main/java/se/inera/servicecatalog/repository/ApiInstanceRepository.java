package se.inera.servicecatalog.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import se.inera.servicecatalog.model.ApiInstance;

import java.util.List;

public interface ApiInstanceRepository extends JpaRepository<ApiInstance, String> {
    List<ApiInstance> findByLogicalAddressAndInteroperabilitySpecificationId(String logicalAddress, String interoperabilitySpecificationId);
    List<ApiInstance> findByLogicalAddressAndInteroperabilitySpecificationIdAndStatus(String logicalAddress, String interoperabilitySpecificationId, String status);
}
