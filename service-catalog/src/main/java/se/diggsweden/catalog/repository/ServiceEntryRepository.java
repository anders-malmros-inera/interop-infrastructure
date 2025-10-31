package se.diggsweden.catalog.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import se.diggsweden.catalog.model.ServiceEntry;

import java.util.UUID;

public interface ServiceEntryRepository extends JpaRepository<ServiceEntry, UUID> {
}
