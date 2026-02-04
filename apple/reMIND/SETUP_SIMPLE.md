# reMIND Watch App - Simple Setup (No Build Scripts)

## Quick Setup - No Build Scripts Required!

This is the simplest way to configure your Azure credentials without build scripts or `.xcconfig` files.

### Option 1: Using Info.plist (Recommended - Simplest)

1. **Open the project in Xcode**

2. **Select the "reMIND Watch App" target**

3. **Go to the "Info" tab**

4. **Add these custom keys:**
   - Right-click in the Custom Target Properties section
   - Add these three entries:
     - Key: `AZURE_API_KEY`, Type: String, Value: `your_api_key_here`
     - Key: `AZURE_RESOURCE_NAME`, Type: String, Value: `your_resource_name`
     - Key: `AZURE_API_VERSION`, Type: String, Value: `2025-10-01`

5. **Done!** The app will read these at runtime.

**Note:** These values will be in the Info.plist which is compiled into the app but visible in the project. For more security, use Option 2.

### Option 2: Manual BuildConfiguration.swift (More Secure)

Simply edit the `BuildConfiguration.swift` file directly:

1. Open `reMIND Watch App/Configuration/BuildConfiguration.swift`

2. Replace the placeholder values:
   ```swift
   enum BuildConfiguration {
       static let azureAPIKey = "your_actual_api_key_here"
       static let azureResourceName = "your_resource_name_here"
       static let azureAPIVersion = "2025-10-01"

       // ... rest stays the same
   }
   ```

3. **Add to .gitignore** (already done) so your credentials aren't committed

4. Build and run!

**Note:** This file is already in `.gitignore`, so your credentials won't be committed to git.

### Option 3: User-Defined Build Settings (For CI/CD)

1. **Select "reMIND Watch App" target**

2. **Go to "Build Settings" tab**

3. **Filter for "User-Defined"**

4. **Click "+" and add:**
   - `AZURE_API_KEY` = `your_api_key`
   - `AZURE_RESOURCE_NAME` = `your_resource_name`
   - `AZURE_API_VERSION` = `2025-10-01`

5. **These will be available to the build script** (but stored in project.pbxproj)

⚠️ **Warning:** User-defined settings in Xcode are stored in `project.pbxproj` which IS committed to git. Only use this for development/testing.

---

## Recommendation

**For now, use Option 2** (Manual BuildConfiguration.swift) - it's:
- ✅ Simple (just edit one file)
- ✅ Secure (file is in .gitignore)
- ✅ No build scripts needed
- ✅ Works immediately

**For production/team environments**, consider implementing a proper secrets management solution.

---

## Getting Azure Credentials

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to your Azure Speech Service resource
3. Go to "Keys and Endpoint"
4. Copy **Key 1** → use as `azureAPIKey`
5. The resource name is in the overview → use as `azureResourceName`

---

## Troubleshooting

**Build fails with sandbox error:**
- Remove any build phase scripts you may have added
- Use Option 2 (manual BuildConfiguration.swift) instead

**App shows "not configured" error:**
- Make sure you replaced ALL placeholder values in BuildConfiguration.swift
- Verify the values don't contain "YOUR_" or "_HERE"
