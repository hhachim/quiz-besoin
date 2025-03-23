# Guide d'Implémentation d'un Plugin pour l'API Quiz
**Version 1.0.0**

Ce guide détaille les étapes à suivre pour créer un nouveau plugin compatible avec l'architecture modulaire de l'API Quiz.

## Table des matières

1. [Création d'un nouveau plugin](#création-dun-nouveau-plugin)
2. [Structure recommandée](#structure-recommandée)
3. [Implémentation de l'interface QuizPlugin](#implémentation-de-linterface-quizplugin)
4. [Extension des fonctionnalités](#extension-des-fonctionnalités)
5. [Modèle de données](#modèle-de-données)
6. [Contrôleurs REST](#contrôleurs-rest)
7. [Services](#services)
8. [Configuration](#configuration)
9. [Tests](#tests)
10. [Déploiement](#déploiement)
11. [Exemple complet](#exemple-complet)

## Création d'un nouveau plugin

Pour créer un nouveau plugin, commencez par créer un nouveau module Maven/Gradle :

```xml
<!-- pom.xml du plugin -->
<project>
    <modelVersion>4.0.0</modelVersion>
    <parent>
        <groupId>com.quizapi</groupId>
        <artifactId>quiz-api</artifactId>
        <version>1.0.0</version>
    </parent>
    
    <artifactId>quiz-plugin-example</artifactId>
    <name>Quiz API - Example Plugin</name>
    
    <dependencies>
        <!-- Dépendance sur le Core -->
        <dependency>
            <groupId>com.quizapi</groupId>
            <artifactId>quiz-core</artifactId>
            <version>${project.version}</version>
            <scope>provided</scope>
        </dependency>
        
        <!-- Autres dépendances -->
    </dependencies>
</project>
```

## Structure recommandée

Organisez votre plugin selon cette structure :

```
quiz-plugin-example/
├── pom.xml
└── src/
    ├── main/
    │   ├── java/
    │   │   └── com/quizapi/plugins/example/
    │   │       ├── ExamplePlugin.java       # Implémentation principale
    │   │       ├── config/                  # Configuration
    │   │       ├── controller/              # Contrôleurs REST
    │   │       ├── model/                   # Entités et DTOs
    │   │       ├── repository/              # Accès aux données
    │   │       └── service/                 # Services
    │   └── resources/
    │       ├── db/migration/               # Migrations de schéma
    │       └── META-INF/
    │           └── services/               # Fichier pour ServiceLoader
    └── test/
        └── java/
            └── com/quizapi/plugins/example/ # Tests unitaires
```

## Implémentation de l'interface QuizPlugin

Chaque plugin doit implémenter l'interface `QuizPlugin` :

```java
package com.quizapi.plugins.example;

import com.quizapi.core.plugin.QuizPlugin;
import org.springframework.stereotype.Component;

@Component
public class ExamplePlugin implements QuizPlugin {
    
    private boolean enabled = false;
    
    @Override
    public String getId() {
        return "quiz-example-plugin";
    }
    
    @Override
    public String getName() {
        return "Example Plugin";
    }
    
    @Override
    public String getVersion() {
        return "1.0.0";
    }
    
    @Override
    public String getDescription() {
        return "A simple example plugin demonstrating the plugin architecture";
    }
    
    @Override
    public void initialize() {
        // Logique d'initialisation
        System.out.println("Example plugin initialized");
    }
    
    @Override
    public void shutdown() {
        // Logique de nettoyage
        System.out.println("Example plugin shutdown");
    }
    
    @Override
    public boolean isEnabled() {
        return enabled;
    }
    
    @Override
    public void setEnabled(boolean enabled) {
        this.enabled = enabled;
    }
}
```

## Extension des fonctionnalités

### Enregistrement via ServiceLoader

Pour permettre la découverte automatique de votre plugin, créez un fichier dans :
`src/main/resources/META-INF/services/com.quizapi.core.plugin.QuizPlugin`

Contenu du fichier :
```
com.quizapi.plugins.example.ExamplePlugin
```

### Extension de l'API REST

Si votre plugin doit exposer des endpoints REST, implémentez l'interface `SpringMvcPlugin` :

```java
package com.quizapi.plugins.example;

import com.quizapi.core.plugin.QuizPlugin;
import com.quizapi.core.plugin.SpringMvcPlugin;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import java.util.HashSet;
import java.util.Set;

@Component
public class ExamplePlugin implements QuizPlugin, SpringMvcPlugin {
    
    @Autowired
    private ExampleController exampleController;
    
    // ... autres méthodes de QuizPlugin
    
    @Override
    public Set<Object> getControllers() {
        Set<Object> controllers = new HashSet<>();
        controllers.add(exampleController);
        return controllers;
    }
}
```

## Modèle de données

### Entités

Définissez vos entités en suivant les conventions JPA et en préfixant les noms de tables :

```java
package com.quizapi.plugins.example.model;

import javax.persistence.*;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "plugin_example_items")
public class ExampleItem {
    
    @Id
    @GeneratedValue(strategy = GenerationType.AUTO)
    private UUID id;
    
    @Column(nullable = false)
    private String name;
    
    @Column
    private String description;
    
    @ManyToOne
    @JoinColumn(name = "quiz_id")
    private Quiz quiz;  // Référence à une entité du Core
    
    @Column(nullable = false)
    private LocalDateTime createdAt = LocalDateTime.now();
    
    // Getters et setters
}
```

### Migrations

Si votre plugin nécessite des modifications de schéma, utilisez Flyway ou Liquibase :

```sql
-- src/main/resources/db/migration/V1__create_example_tables.sql
CREATE TABLE plugin_example_items (
    id UUID PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    quiz_id UUID REFERENCES quizzes(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

## Contrôleurs REST

Créez vos contrôleurs REST en suivant la convention de préfixage des URLs :

```java
package com.quizapi.plugins.example.controller;

import com.quizapi.plugins.example.dto.ExampleItemDTO;
import com.quizapi.plugins.example.service.ExampleService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/example")  // Préfixé avec le nom du plugin
public class ExampleController {
    
    @Autowired
    private ExampleService exampleService;
    
    @GetMapping("/items")
    public ResponseEntity<List<ExampleItemDTO>> getAllItems() {
        return ResponseEntity.ok(exampleService.findAllItems());
    }
    
    @GetMapping("/items/{id}")
    public ResponseEntity<ExampleItemDTO> getItem(@PathVariable UUID id) {
        return exampleService.findItemById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }
    
    @PostMapping("/items")
    public ResponseEntity<ExampleItemDTO> createItem(@RequestBody ExampleItemDTO dto) {
        return ResponseEntity.ok(exampleService.createItem(dto));
    }
    
    // Autres méthodes
}
```

## Services

Implémentez vos services business :

```java
package com.quizapi.plugins.example.service;

import com.quizapi.plugins.example.dto.ExampleItemDTO;
import com.quizapi.plugins.example.model.ExampleItem;
import com.quizapi.plugins.example.repository.ExampleItemRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
public class ExampleService {
    
    @Autowired
    private ExampleItemRepository exampleItemRepository;
    
    public List<ExampleItemDTO> findAllItems() {
        return exampleItemRepository.findAll().stream()
                .map(this::convertToDTO)
                .collect(Collectors.toList());
    }
    
    public Optional<ExampleItemDTO> findItemById(UUID id) {
        return exampleItemRepository.findById(id)
                .map(this::convertToDTO);
    }
    
    @Transactional
    public ExampleItemDTO createItem(ExampleItemDTO dto) {
        ExampleItem item = new ExampleItem();
        item.setName(dto.getName());
        item.setDescription(dto.getDescription());
        // Autres mappings
        
        item = exampleItemRepository.save(item);
        return convertToDTO(item);
    }
    
    private ExampleItemDTO convertToDTO(ExampleItem item) {
        ExampleItemDTO dto = new ExampleItemDTO();
        dto.setId(item.getId());
        dto.setName(item.getName());
        dto.setDescription(item.getDescription());
        // Autres mappings
        return dto;
    }
}
```

## Configuration

Configurez votre plugin avec des propriétés spécifiques :

```java
package com.quizapi.plugins.example.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;

@Configuration
@ConfigurationProperties(prefix = "quiz.plugin.example")
public class ExamplePluginConfig {
    
    private boolean featureEnabled = true;
    private int maxItems = 100;
    private String apiKey;
    
    // Getters et setters
}
```

Et utilisez un fichier de configuration pour les valeurs par défaut :

```properties
# src/main/resources/application-example-plugin.properties
quiz.plugin.example.feature-enabled=true
quiz.plugin.example.max-items=100
```

## Tests

Assurez-vous de tester votre plugin de manière isolée et en intégration :

```java
package com.quizapi.plugins.example;

import com.quizapi.core.plugin.PluginRegistry;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
public class ExamplePluginTest {
    
    @Autowired
    private ExamplePlugin examplePlugin;
    
    @Autowired
    private PluginRegistry pluginRegistry;
    
    @Test
    void pluginInitialization() {
        // Vérifier l'enregistrement
        assertTrue(pluginRegistry.getAllPlugins().contains(examplePlugin));
        
        // Tester l'activation
        pluginRegistry.enablePlugin(examplePlugin.getId());
        assertTrue(examplePlugin.isEnabled());
        
        // Tester la désactivation
        pluginRegistry.disablePlugin(examplePlugin.getId());
        assertFalse(examplePlugin.isEnabled());
    }
}
```

## Déploiement

Pour déployer votre plugin :

1. Construisez le JAR du plugin : `mvn package`
2. Assurez-vous que le JAR contient bien le fichier de configuration ServiceLoader
3. Placez le JAR dans le classpath de l'application principale ou dans un répertoire dédié aux plugins
4. Redémarrez l'application ou utilisez l'API `/api/v1/admin/plugins/refresh` pour découvrir le nouveau plugin
5. Activez le plugin via l'API `/api/v1/admin/plugins/{id}/enable`

## Exemple complet

Un exemple complet de plugin est disponible sur le dépôt GitHub du projet :
[quiz-api-plugin-example](https://github.com/quizapi/quiz-api-plugin-example)

Ce dépôt contient un plugin fonctionnel avec toutes les bonnes pratiques et peut servir de référence pour développer vos propres plugins.