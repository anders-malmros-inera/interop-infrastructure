package se.inera.servicecatalog.repository;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import se.inera.servicecatalog.model.ApiInstance;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.OffsetDateTime;
import java.util.List;

@DataJpaTest
public class ApiInstanceRepositoryTest {

    @Autowired
    private ApiInstanceRepository repo;

    @Test
    void testSaveAndFind() {
        ApiInstance ai = new ApiInstance();
        ai.setId(java.util.UUID.randomUUID().toString());
        ai.setLogicalAddress("TEST-1");
        ai.setInteroperabilitySpecificationId("spec1");
        ai.setCreatedAt(OffsetDateTime.now());
        ai.setUpdatedAt(OffsetDateTime.now());
        repo.save(ai);

        List<ApiInstance> found = repo.findByLogicalAddressAndInteroperabilitySpecificationId("TEST-1", "spec1");
        assertThat(found).isNotEmpty();
    }
}
