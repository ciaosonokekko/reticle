import Foundation

// Lightweight in-code localization (no .lproj bundles). Supported: EN (default), IT, FR, ES.
enum L10n {
    enum Key {
        case openArrange
        case grantAccessibility
        case accessibilityGranted
        case about
        case quit
        case axGrantedTitle
        case axGrantedBody
        case axNeededTitle
        case axNeededBody
        case openSettings
        case cancel
        case ok
        case aboutTagline
        case aboutSnap
        case linkGithub
        case linkCoffee
    }

    // Resolved once from the user's preferred languages; defaults to English.
    static let lang: String = {
        let supported = ["en", "it", "fr", "es"]
        for pref in Locale.preferredLanguages {
            let code = String(pref.prefix(2)).lowercased()
            if supported.contains(code) { return code }
        }
        return "en"
    }()

    static func t(_ key: Key) -> String {
        let table = strings[lang] ?? strings["en"]!
        return table[key] ?? strings["en"]![key] ?? ""
    }

    private static let strings: [String: [Key: String]] = [
        "en": [
            .openArrange: "Open Arrange Displays",
            .grantAccessibility: "Grant Accessibility…",
            .accessibilityGranted: "Accessibility: granted ✓",
            .about: "About Reticle",
            .quit: "Quit",
            .axGrantedTitle: "Accessibility already granted",
            .axGrantedBody: "Reticle has the required permissions. The overlay is active.",
            .axNeededTitle: "Enable Reticle in Accessibility",
            .axNeededBody: """
            Reticle needs Accessibility permission to draw alignment guides.

            1. Open System Settings → Privacy & Security → Accessibility.
            2. Find “Reticle” in the list — it has already been added.
            3. Flip its toggle on.

            You don't need to browse or drag the app: it's already there, just enable it.
            """,
            .openSettings: "Open Settings",
            .cancel: "Cancel",
            .ok: "OK",
            .aboutTagline: "Pixel-perfect alignment guides for the macOS Arrange Displays panel.",
            .aboutSnap: "Lights up an accent-colored line when two displays' centers align.",
            .linkGithub: "GitHub repository",
            .linkCoffee: "Buy me a coffee ☕",
        ],
        "it": [
            .openArrange: "Apri Disponi schermi",
            .grantAccessibility: "Concedi Accessibilità…",
            .accessibilityGranted: "Accessibilità: concessa ✓",
            .about: "Informazioni su Reticle",
            .quit: "Esci",
            .axGrantedTitle: "Accessibilità già concessa",
            .axGrantedBody: "Reticle ha i permessi necessari. L'overlay è attivo.",
            .axNeededTitle: "Abilita Reticle in Accessibilità",
            .axNeededBody: """
            Reticle ha bisogno del permesso di Accessibilità per disegnare le guide di allineamento.

            1. Apri Impostazioni di Sistema → Privacy e sicurezza → Accessibilità.
            2. Trova “Reticle” nell'elenco: è già stata aggiunta.
            3. Attiva il suo interruttore.

            Non devi cercare o trascinare l'app: è già presente, basta attivarla.
            """,
            .openSettings: "Apri Impostazioni",
            .cancel: "Annulla",
            .ok: "OK",
            .aboutTagline: "Guide di allineamento al pixel per il pannello Disponi schermi di macOS.",
            .aboutSnap: "Accende una linea nel colore d'accento quando i centri di due schermi si allineano.",
            .linkGithub: "Repository GitHub",
            .linkCoffee: "Offrimi un caffè ☕",
        ],
        "fr": [
            .openArrange: "Ouvrir Disposer les écrans",
            .grantAccessibility: "Autoriser l'Accessibilité…",
            .accessibilityGranted: "Accessibilité : autorisée ✓",
            .about: "À propos de Reticle",
            .quit: "Quitter",
            .axGrantedTitle: "Accessibilité déjà autorisée",
            .axGrantedBody: "Reticle dispose des autorisations nécessaires. L'overlay est actif.",
            .axNeededTitle: "Activer Reticle dans l'Accessibilité",
            .axNeededBody: """
            Reticle a besoin de l'autorisation d'Accessibilité pour dessiner les repères d'alignement.

            1. Ouvrez Réglages Système → Confidentialité et sécurité → Accessibilité.
            2. Trouvez « Reticle » dans la liste : elle a déjà été ajoutée.
            3. Activez son interrupteur.

            Pas besoin de chercher ou de glisser l'app : elle est déjà là, il suffit de l'activer.
            """,
            .openSettings: "Ouvrir les Réglages",
            .cancel: "Annuler",
            .ok: "OK",
            .aboutTagline: "Repères d'alignement au pixel près pour le panneau Disposer les écrans de macOS.",
            .aboutSnap: "Affiche une ligne dans la couleur d'accentuation quand les centres de deux écrans s'alignent.",
            .linkGithub: "Dépôt GitHub",
            .linkCoffee: "Offrez-moi un café ☕",
        ],
        "es": [
            .openArrange: "Abrir Organizar pantallas",
            .grantAccessibility: "Conceder Accesibilidad…",
            .accessibilityGranted: "Accesibilidad: concedida ✓",
            .about: "Acerca de Reticle",
            .quit: "Salir",
            .axGrantedTitle: "Accesibilidad ya concedida",
            .axGrantedBody: "Reticle tiene los permisos necesarios. La superposición está activa.",
            .axNeededTitle: "Activa Reticle en Accesibilidad",
            .axNeededBody: """
            Reticle necesita permiso de Accesibilidad para dibujar las guías de alineación.

            1. Abre Ajustes del Sistema → Privacidad y seguridad → Accesibilidad.
            2. Busca “Reticle” en la lista: ya se ha añadido.
            3. Activa su interruptor.

            No necesitas buscar ni arrastrar la app: ya está ahí, solo actívala.
            """,
            .openSettings: "Abrir Ajustes",
            .cancel: "Cancelar",
            .ok: "OK",
            .aboutTagline: "Guías de alineación al píxel para el panel Organizar pantallas de macOS.",
            .aboutSnap: "Enciende una línea con el color de acento cuando los centros de dos pantallas se alinean.",
            .linkGithub: "Repositorio de GitHub",
            .linkCoffee: "Invítame a un café ☕",
        ],
    ]
}
