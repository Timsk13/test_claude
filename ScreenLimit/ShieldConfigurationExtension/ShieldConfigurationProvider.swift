import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Personnalise l'écran affiché quand l'utilisateur ouvre une app bloquée.
class ShieldConfigurationProvider: ShieldConfigurationDataSource {

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeConfiguration(name: application.localizedDisplayName)
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration(name: application.localizedDisplayName)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfiguration(name: webDomain.domain)
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration(name: webDomain.domain)
    }

    private func makeConfiguration(name: String?) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor.systemIndigo.withAlphaComponent(0.4),
            icon: UIImage(systemName: "hourglass.bottomhalf.filled"),
            title: ShieldConfiguration.Label(text: "Temps écoulé", color: .white),
            subtitle: ShieldConfiguration.Label(
                text: "Tu as atteint ta limite quotidienne pour \(name ?? "cette app"). Rendez-vous demain !",
                color: .white
            ),
            primaryButtonLabel: ShieldConfiguration.Label(text: "OK", color: .white),
            primaryButtonBackgroundColor: .systemIndigo
        )
    }
}
