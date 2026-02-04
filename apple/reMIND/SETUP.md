# reMIND Watch App - Setup Guide

## Build Configuration Setup

This project uses **build-time configuration** for Azure credentials. Credentials are set via Xcode build settings and never stored in source control or accessible at runtime.

### Quick Setup

1. **Copy the configuration template:**
   ```bash
   cp Config.template.xcconfig Config.xcconfig
   ```

2. **Edit `Config.xcconfig` with your Azure credentials:**
   ```
   AZURE_API_KEY = your_actual_api_key_here
   AZURE_RESOURCE_NAME = your_resource_name_here
   AZURE_API_VERSION = 2025-10-01
   ```

3. **Add Config.xcconfig to Xcode project:**
   - Open `reMIND.xcodeproj` in Xcode
   - Right-click on the project root in the navigator
   - Select "Add Files to reMIND"
   - Select `Config.xcconfig`
   - **Important:** Uncheck "Copy items if needed" (we want to reference it, not copy it)

4. **Configure project to use Config.xcconfig:**
   - Select the project in the navigator
   - Select the "Info" tab
   - Under "Configurations", for both Debug and Release:
     - Expand the "reMIND Watch App" target
     - Set the configuration to "Config"

5. **Add Build Phase to generate BuildConfiguration.swift:**
   - Select "reMIND Watch App" target
   - Go to "Build Phases" tab
   - Click "+" and select "New Run Script Phase"
   - Drag it to run **before** "Compile Sources"
   - Name it "Generate Build Configuration"
   - Add this script:
     ```bash
     "${SRCROOT}/scripts/generate-config.sh"
     ```

6. **Add Input/Output Files to Build Phase:**
   - In the Run Script phase you just created:
   - **Input Files:** Add `$(SRCROOT)/Config.xcconfig`
   - **Output Files:** Add `$(SRCROOT)/reMIND Watch App/Configuration/BuildConfiguration.swift`
   - This ensures the script only runs when Config.xcconfig changes

7. **Build the project:**
   ```bash
   xcodebuild -scheme "reMIND Watch App" clean build
   ```

### How It Works

1. **`Config.xcconfig`**: Contains your Azure credentials as Xcode build settings
   - This file is in `.gitignore` and never committed to source control
   - `Config.template.xcconfig` is the template (committed) with placeholder values

2. **`scripts/generate-config.sh`**: Build phase script that runs before compilation
   - Reads build settings from `Config.xcconfig`
   - Generates `BuildConfiguration.swift` with the values
   - This file is also in `.gitignore`

3. **`BuildConfiguration.swift`**: Auto-generated Swift file
   - Contains the credentials as compile-time constants
   - Used by `AzureConfig` to configure the app
   - **Never edit this file manually** - it's regenerated on every build

4. **`AzureConfig`**: Reads from `BuildConfiguration`
   - No runtime configuration
   - No user-accessible settings
   - Configuration happens at build time only

### Security Notes

- ✅ **Credentials never committed to git** (Config.xcconfig is in .gitignore)
- ✅ **Credentials compiled into binary** (not accessible at runtime via plist reading)
- ✅ **No runtime configuration UI** (users can't access/change credentials)
- ✅ **Different configs per environment** (can create Config.Debug.xcconfig, Config.Release.xcconfig, etc.)

### Alternative: User-Defined Build Settings

If you prefer not to use `.xcconfig` files, you can set build settings directly in Xcode:

1. Select "reMIND Watch App" target
2. Go to "Build Settings" tab
3. Click "+" and select "Add User-Defined Setting"
4. Add:
   - `AZURE_API_KEY` = your_api_key
   - `AZURE_RESOURCE_NAME` = your_resource_name
   - `AZURE_API_VERSION` = 2025-10-01

⚠️ **Note:** User-defined build settings in Xcode are stored in `project.pbxproj`, which IS committed to git. For production, use `.xcconfig` files instead.

### Environment-Specific Configurations

To support multiple environments (dev, staging, production):

1. Create multiple config files:
   ```
   Config.Development.xcconfig
   Config.Staging.xcconfig
   Config.Production.xcconfig
   ```

2. Set different configurations in Xcode project settings

3. Switch between them by selecting different configurations when building

### Troubleshooting

**"YOUR_API_KEY_HERE" appears in app:**
- The build script didn't run
- Check that the Run Script phase is before "Compile Sources"
- Make sure `Config.xcconfig` exists and has your credentials

**Build fails with missing BuildConfiguration:**
- Run the generate script manually: `./scripts/generate-config.sh`
- Make sure `SRCROOT` environment variable is set correctly

**Credentials exposed in binary:**
- This is expected - they're compiled in
- For production, consider using a secure key management service
- Or implement certificate-based authentication with Azure

### Getting Azure Credentials

1. Go to [Azure Portal](https://portal.azure.com)
2. Create or navigate to your Azure Speech Service resource
3. Go to "Keys and Endpoint"
4. Copy **Key 1** or **Key 2** → use as `AZURE_API_KEY`
5. The resource name is in the overview (e.g., "my-speech-service") → use as `AZURE_RESOURCE_NAME`

### CI/CD Integration

For CI/CD pipelines (GitHub Actions, etc.):

```yaml
- name: Create Config
  env:
    AZURE_API_KEY: ${{ secrets.AZURE_API_KEY }}
    AZURE_RESOURCE_NAME: ${{ secrets.AZURE_RESOURCE_NAME }}
  run: |
    cat > Config.xcconfig <<EOF
    AZURE_API_KEY = $AZURE_API_KEY
    AZURE_RESOURCE_NAME = $AZURE_RESOURCE_NAME
    AZURE_API_VERSION = 2025-10-01
    EOF

- name: Build
  run: xcodebuild -scheme "reMIND Watch App" build
```

Store your credentials in GitHub Secrets, not in the workflow file.
