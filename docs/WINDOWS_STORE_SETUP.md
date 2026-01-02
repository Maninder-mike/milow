# Windows Store Release Setup Guide

This guide explains how to configure your Microsoft Partner Center account and GitHub repository to automate Windows app releases.

## 1. Prerequisites

- **Microsoft Partner Center Account**: You must have a developer account.
- **Reserved App Name**: You must have created your app in Partner Center and reserved the name "Milow".

## 2. Get Azure AD Credentials (for CI/CD)

To allow GitHub Actions to upload to the store, you need an Azure AD application.

1. **Register a new application** in [Azure Portal](https://portal.azure.com/#blade/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/RegisteredApps) (or use "GitHub-Action-App" if you already created it).
    - Go to **App registrations** > **New registration**.
    - Name: `GitHub-Action-App` (or similar).
    - Supported account types: **Single tenant**.
    - Redirect URI: Leave blank.
    - Click **Register**.

2. **Get IDs from the Overview page**:
    - **Application (client) ID**: Save this (for `WINDOWS_STORE_CLIENT_ID`).
    - **Directory (tenant) ID**: Save this (for `WINDOWS_STORE_TENANT_ID`).

3. **Create a Client Secret**:
    - Go to **Certificates & secrets** > **Client secrets** > **New client secret**.
    - Description: `GitHub Actions Secret`.
    - Expires: Choose a duration (e.g., 24 months).
    - Click **Add**.
    - **Copy the Value immediately**. This is your `WINDOWS_STORE_CLIENT_SECRET`.
    > [!IMPORTANT]
    > **Do NOT use the "Object ID"**. The Object ID is public. The **Client Secret** is a private key found ONLY in the "Certificates & secrets" tab. It is sometimes called the "Value" in the list of secrets.

## 3. Link Azure App to Partner Center

1. Go to [Partner Center](https://partner.microsoft.com/dashboard).
2. Navigate to **Account settings** (gear icon) > **User management**.
3. Click **Azure AD applications**.
4. Click **Add Azure AD application**.
5. Select the app you created (check the App ID matches).
6. Role: **Manager** (or **Developer**).
7. Click **Save**.

## 4. Configure GitHub Secrets

Go to your GitHub Repository > **Settings** > **Secrets and variables** > **Actions** > **New repository secret**.

Add the following secrets:

| Secret Name | Value |
| :--- | :--- |
| `WINDOWS_STORE_TENANT_ID` | The Directory (tenant) ID from Step 2. |
| `WINDOWS_STORE_CLIENT_ID` | The Application (client) ID from Step 2. |
| `WINDOWS_STORE_CLIENT_SECRET` | The Client Secret Value from Step 2. |
| `WINDOWS_PAD_TOKEN` | (Optional) If using manual Partner Center token. |

## 5. Verify `pubspec.yaml` Configuration

Open `apps/terminal/pubspec.yaml` and ensure the `msix_config` matches your Partner Center "Product Identity" page:

```yaml
msix_config:
  display_name: Milow Terminal
  publisher_display_name: Maninder Singh
  identity_name: ManinderSingh.milowterminal  # MUST match Partner Center Package/Identity/Name
  publisher: CN=503D7524-2660-491B-86EF-F923C5886DDE # MUST match Partner Center Package/Identity/Publisher
  store: true
```

## 6. Certificate (Important)

For Microsoft Store, the store signs the package for you. However, you still need to sign the MSIX for it to be installed locally or for the store to accept it in some flows.
The `msix` package handles a self-signed certificate automatically for testing.
For Store submission, **you do NOT strictly need a bought certificate** if you let the Store manage it, BUT the `msix` tool needs to sign the local package.
The workflow uses a self-signed cert generated on the fly or the one managed by the `msix` tool.

**Note**: To publish to the Store, we use the credentials from Step 2.
