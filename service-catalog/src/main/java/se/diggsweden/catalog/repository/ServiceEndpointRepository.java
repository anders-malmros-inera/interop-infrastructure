package se.diggsweden.catalog.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import se.diggsweden.catalog.model.ServiceEndpoint;

import java.util.UUID;

public interface ServiceEndpointRepository extends JpaRepository<ServiceEndpoint, UUID> {
}
