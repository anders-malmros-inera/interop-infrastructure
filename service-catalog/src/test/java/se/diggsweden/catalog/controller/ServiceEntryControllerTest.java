package se.diggsweden.catalog.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.security.test.context.support.WithMockUser;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import se.diggsweden.catalog.dto.ServiceEntryDto;
import se.diggsweden.catalog.service.ServiceEntryService;

import java.util.List;
import java.util.UUID;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.csrf;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;

@WebMvcTest(ServiceEntryController.class)
class ServiceEntryControllerTest {

    @Autowired
    private MockMvc mvc;

    @Autowired
    private ObjectMapper mapper;

    @MockBean
    private ServiceEntryService service;

    @Test
    @WithMockUser(authorities = "SCOPE_catalog.read")
    void list_returnsOkAndJson() throws Exception {
        ServiceEntryDto d = new ServiceEntryDto();
        d.setId(UUID.randomUUID());
        d.setName("MyService");
        when(service.list()).thenReturn(List.of(d));

        mvc.perform(get("/api/v1/services").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].name").value("MyService"));
    }

    @Test
    @WithMockUser(authorities = "SCOPE_catalog.write")
    void create_returns201WithLocation() throws Exception {
        ServiceEntryDto in = new ServiceEntryDto();
        in.setName("CreateMe");
        ServiceEntryDto created = new ServiceEntryDto();
        created.setId(UUID.randomUUID());
        created.setName("CreateMe");

        when(service.create(any(ServiceEntryDto.class))).thenReturn(created);

    mvc.perform(post("/api/v1/services")
            .with(csrf())
            .contentType(MediaType.APPLICATION_JSON)
            .content(mapper.writeValueAsString(in)))
                .andExpect(status().isCreated())
                .andExpect(header().string("Location", org.hamcrest.Matchers.containsString("/api/v1/services/")));
    }
}
