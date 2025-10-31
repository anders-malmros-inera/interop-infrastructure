package se.diggsweden.catalog.service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;
import se.diggsweden.catalog.dto.ServiceEntryDto;
import se.diggsweden.catalog.model.ServiceEntry;
import se.diggsweden.catalog.repository.ServiceEntryRepository;

import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class ServiceEntryServiceTest {

    @Mock
    private ServiceEntryRepository repository;

    private ServiceEntryService service;

    @BeforeEach
    void setUp() {
        MockitoAnnotations.openMocks(this);
        service = new ServiceEntryService(repository);
    }

    @Test
    void create_shouldPersistAndReturnDto() {
        ServiceEntryDto dto = new ServiceEntryDto();
        dto.setName("My Service");

        ServiceEntry saved = new ServiceEntry();
        saved.setId(UUID.randomUUID());
        saved.setName(dto.getName());

        when(repository.save(any(ServiceEntry.class))).thenReturn(saved);

        ServiceEntryDto result = service.create(dto);

        assertNotNull(result.getId());
        assertEquals("My Service", result.getName());
        verify(repository, times(1)).save(any(ServiceEntry.class));
    }

    @Test
    void get_shouldReturnDtoWhenFound() {
        UUID id = UUID.randomUUID();
        ServiceEntry e = new ServiceEntry();
        e.setId(id);
        e.setName("S");
        when(repository.findById(id)).thenReturn(Optional.of(e));

        Optional<ServiceEntryDto> res = service.get(id);
        assertTrue(res.isPresent());
        assertEquals(id, res.get().getId());
    }
}
