# GitHub Actions Signing Setup

To enable proper release signing for APK builds in GitHub Actions, you need to configure the following secrets in your repository.

## Required GitHub Secrets

Go to your repository → Settings → Secrets and variables → Actions → New repository secret

### 1. KEYSTORE_BASE64
Your keystore file encoded in base64.

**To generate:**
```bash
# If you have an existing keystore
base64 -i android/upload-keystore.jks

# Or create a new keystore first
keytool -genkey -v -keystore android/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
base64 -i android/upload-keystore.jks
```

Copy the entire base64 output and save it as the `KEYSTORE_BASE64` secret.

### 2. KEYSTORE_PASSWORD
The password for your keystore file.

### 3. KEY_ALIAS
The alias name for your key (e.g., "upload").

### 4. KEY_PASSWORD
The password for your key alias.

## Fallback Behavior

If these secrets are not configured:
- The workflow will still run successfully
- The APK will be signed with debug signing
- This is suitable for testing but **NOT for production release**

## Local Development

For local development, create a `key.properties` file in the `android/` directory:

```properties
storePassword=your_store_password
keyPassword=your_key_password
keyAlias=your_key_alias
storeFile=../upload-keystore.jks
```

**Important:** Never commit `key.properties` or `*.jks` files to git. They are already in `.gitignore`.
