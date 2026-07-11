import AuthenticationServices
import os.log

class CredentialProviderViewController: ASCredentialProviderViewController {

    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        // TODO: Access shared App Group Keychain or UserDefaults
        // Read stored FIDO2 passkeys from the Flutter app's vault
        // Return a list of available passkeys for the requested serviceIdentifier (domain)
        
        let credentialIdentities: [ASPasswordCredentialIdentity] = []
        self.extensionContext.completeRequest(withSelectedCredential: nil, deletedCredentialIdentities: [], updatedCredentialIdentities: credentialIdentities)
    }

    override func provideCredentialWithoutUserInteraction(for credentialIdentity: ASCredentialIdentity) {
        // TODO: Auto-fill without prompt if possible
        self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.userInteractionRequired.rawValue, userInfo: nil))
    }

    override func prepareInterfaceToProvideCredential(for credentialIdentity: ASCredentialIdentity) {
        // TODO: Show UI to authenticate user (e.g. FaceID via LocalAuthentication)
        // Then retrieve private key from vault and sign the assertion
    }

    override func prepareInterfaceForExtensionConfiguration() {
        // TODO: UI for when user configures extension in Settings
    }
}
