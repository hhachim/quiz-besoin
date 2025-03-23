# Architecture Modulaire pour l'API Quiz
**Version 1.0.0**

## Table des matières

1. [Introduction](#introduction)
2. [Vision et principes](#vision-et-principes)
3. [Architecture Core + Plugins](#architecture-core--plugins)
   1. [Module Core](#module-core)
   2. [Système de plugins](#système-de-plugins)
   3. [Types de plugins](#types-de-plugins)
4. [Structure du projet](#structure-du-projet)
5. [Modèle de données](#modèle-de-données)
6. [Mécanisme de plugins](#mécanisme-de-plugins)
   1. [Cycle de vie d'un plugin](#cycle-de-vie-dun-plugin)
   2. [API d'extension](#api-dextension)
   3. [Découverte des plugins](#découverte-des-plugins)
7. [API REST](#api-rest)
8. [Implémentation progressive](#implémentation-progressive)
9. [Bonnes pratiques](#bonnes-pratiques)
10. [FAQ](#faq)

## Introduction

Ce document présente l'architecture modulaire adoptée pour l'API Quiz, basée sur une approche Core + Plugins. Cette architecture permettra de développer et maintenir un système évolutif, flexible et maintenable, où les fonctionnalités peuvent être ajoutées, désactivées ou remplacées de manière indépendante.

## Vision et principes

L'architecture choisie repose sur les principes suivants :

- **Modularité** : L'application est divisée en modules indépendants ayant des responsabilités clairement définies.
- **Extensibilité** : Le système peut être étendu sans modifier le code existant (principe Open/Closed).
- **Découplage** : Les modules interagissent via des interfaces bien définies, minimisant les dépendances directes.
- **Progressivité** : L'application peut évoluer de manière incrémentale, en commençant par un MVP puis en ajoutant des fonctionnalités.
- **Isolation** : Les problèmes dans un module ne doivent pas affecter le reste du système.

## Architecture Core + Plugins

L'architecture se compose de deux parties principales :

1. Un **module Core** qui contient les fonctionnalités essentielles et l'infrastructure nécessaire
2. Des **plugins** qui étendent les fonctionnalités du système de manière indépendante

### Module Core

Le module Core fournit :

- Infrastructure de base (configuration, exceptions, logging)
- Modèle de données fondamental (utilisateurs, quiz, catégories)
- API REST pour les fonctionnalités de base
- Mécanisme de gestion des plugins (découverte, activation, désactivation)
- Services communs réutilisables par les plugins

### Système de plugins

Le système de plugins permet :

- **Découverte automatique** des plugins disponibles
- **Gestion du cycle de vie** (initialisation, arrêt, activation, désactivation)
- **Extension des points d'entrée** de l'API REST
- **Extension du modèle de données** sans modification du schéma existant
- **Configuration individuelle** pour chaque plugin

### Types de plugins

Différents types de plugins peuvent être développés :

1. **Plugins de type de question**
   - Quiz à choix multiples
   - Vrai/Faux
   - Questions ouvertes
   - Texte à trous
   - Association (Matching)
   - Ordonnancement

2. **Plugins fonctionnels**
   - Authentification et autorisation
   - Dépendances entre quiz
   - Tentatives et suivi de progression
   - Statistiques et reporting
   - Gamification (badges, classements)

## Structure du projet

Le projet suit une structure multi-modules avec Maven/Gradle :

```
quiz-api/
├── pom.xml                           # POM parent
├── quiz-core/                        # Module core
│   ├── pom.xml
│   └── src/
├── quiz-api-app/                     # Application principale
│   ├── pom.xml
│   └── src/
├── quiz-plugin-auth/                 # Plugin d'authentification
│   ├── pom.xml
│   └── src/
├── quiz-plugin-mcq/                  # Plugin de questions à choix multiples
│   ├── pom.xml
│   └── src/
...
```

Chaque plugin est un module Maven/Gradle indépendant avec ses propres dépendances, tests et documentation.

## Modèle de données

Le modèle de données est conçu pour s'adapter à cette architecture modulaire :

1. **Tables du Core**
   - Users, Quizzes, Categories, Tags
   - Une table `plugins` pour suivre les plugins installés et leur état

2. **Tables par plugin**
   - Chaque plugin définit ses propres tables avec un préfixe (ex: `plugin_auth_`, `plugin_mcq_`)
   - Les tables peuvent référencer les entités du Core, mais pas l'inverse

### Exemple de schéma Core

```sql
-- Tables du core (socle commun)
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username TEXT UNIQUE NOT NULL,
    email TEXT UNIQUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE quizzes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    description TEXT,
    visibility TEXT CHECK (visibility IN ('public', 'private')) DEFAULT 'private',
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

-- Table pour les plugins
CREATE TABLE plugins (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    version TEXT NOT NULL,
    enabled BOOLEAN DEFAULT false,
    config JSONB,
    installed_at TIMESTAMPTZ DEFAULT now()
);
```

## Mécanisme de plugins

### Cycle de vie d'un plugin

Chaque plugin suit un cycle de vie précis :

1. **Découverte** : Le système détecte les plugins disponibles
2. **Enregistrement** : Le plugin est enregistré auprès du gestionnaire de plugins
3. **Initialisation** : Lorsqu'activé, le plugin initialise ses ressources
4. **Exécution** : Le plugin fournit ses fonctionnalités pendant l'exécution
5. **Arrêt** : Lorsque désactivé, le plugin libère ses ressources
6. **Désinstallation** (optionnel) : Suppression complète du plugin

Interface de base pour les plugins :

```java
public interface QuizPlugin {
    String getId();          // Identifiant unique du plugin
    String getName();        // Nom lisible du plugin
    String getVersion();     // Version du plugin
    String getDescription(); // Description des fonctionnalités
    
    void initialize();       // Appelé à l'activation
    void shutdown();         // Appelé à la désactivation
    boolean isEnabled();     // État actuel
    void setEnabled(boolean enabled);
}
```

### API d'extension

Les plugins peuvent étendre différents aspects du système :

1. **Extension de l'API REST** 
   - Ajout de nouveaux endpoints
   - Modification du comportement d'endpoints existants

2. **Extension du modèle de données**
   - Ajout de nouvelles entités
   - Extension des entités existantes via des tables liées

3. **Extension des services**
   - Remplacement ou décoration de services existants
   - Ajout de nouveaux services

```java
public interface ApiExtensionPoint {
    void registerController(Object controller);   // Ajouter un contrôleur REST
    void registerService(Object service);         // Enregistrer un service
    void registerEventListener(Object listener);  // Écouter les événements système
}
```

### Découverte des plugins

Plusieurs mécanismes de découverte sont supportés :

1. **ServiceLoader** de Java pour découvrir les plugins dans le classpath
2. **Scanning de packages** pour trouver les implémentations annotées
3. **Chargement externe** depuis un répertoire dédié (pour plugins tiers)

```java
// Exemple avec ServiceLoader
ServiceLoader<QuizPlugin> loader = ServiceLoader.load(QuizPlugin.class);
for (QuizPlugin plugin : loader) {
    pluginRegistry.registerPlugin(plugin);
}
```

## API REST

### Endpoints pour la gestion des plugins

Le Core expose une API d'administration pour gérer les plugins :

```
GET    /api/v1/admin/plugins              # Liste tous les plugins
GET    /api/v1/admin/plugins/{id}         # Détails d'un plugin
POST   /api/v1/admin/plugins/{id}/enable  # Active un plugin
POST   /api/v1/admin/plugins/{id}/disable # Désactive un plugin
POST   /api/v1/admin/plugins/refresh      # Rafraîchit la liste des plugins
```

### Extension des endpoints par les plugins

Chaque plugin peut exposer ses propres endpoints, généralement préfixés :

```
GET    /api/v1/mcq/questions              # Endpoint du plugin MCQ
POST   /api/v1/auth/login                 # Endpoint du plugin Auth
GET    /api/v1/dependencies/prerequisites # Endpoint du plugin Dependencies
```

## Implémentation progressive

La mise en œuvre de cette architecture peut suivre une approche progressive :

### Phase 1 : MVP Core
- Développement du Core avec fonctionnalités minimales
- Mise en place de l'infrastructure de plugins
- Premiers tests d'intégration

### Phase 2 : Plugins essentiels
- Plugin de questions à choix multiples
- Plugin d'authentification de base
- Plugin de tentatives

### Phase 3 : Plugins avancés
- Autres types de questions
- Système de dépendances
- Statistiques et reporting

### Phase 4 : Plugins d'enrichissement
- Gamification
- Intégrations externes
- Plugins spécifiques aux clients

## Bonnes pratiques

Pour une implémentation réussie de cette architecture :

1. **Documentation claire** pour chaque plugin
   - API exposée
   - Points d'extension utilisés
   - Dépendances avec d'autres plugins

2. **Tests exhaustifs**
   - Tests unitaires par plugin
   - Tests d'intégration entre plugins
   - Tests de charge pour vérifier l'impact sur les performances

3. **Versionnement sémantique**
   - Chaque plugin suit un versionnement distinct
   - Compatibilité clairement indiquée

4. **Gestion des dépendances**
   - Minimiser les dépendances inter-plugins
   - Documenter les dépendances existantes

## FAQ

**Q: Comment gérer les conflits entre plugins ?**  
R: Chaque plugin opère dans son propre espace et utilise des interfaces bien définies pour interagir avec le Core. Les conflits potentiels sont résolus par le Core qui priorise les plugins selon une politique configurable.

**Q: Quel est l'impact sur les performances ?**  
R: L'architecture modulaire peut avoir un léger impact sur les performances dû à l'indirection supplémentaire. Cependant, les gains en maintenabilité et évolutivité compensent largement ce coût, qui peut être minimisé par des optimisations ciblées.

**Q: Comment assurer la compatibilité lors des mises à jour ?**  
R: Le Core définit des contrats d'API stables et utilise le versionnement sémantique. Les mises à jour incompatibles sont clairement signalées, et des mécanismes de migration sont fournis.

**Q: Comment un plugin peut-il interagir avec un autre plugin ?**  
R: Les plugins peuvent interagir via des services enregistrés auprès du Core. Un plugin peut déclarer des dépendances sur d'autres plugins et accéder à leurs services si disponibles.