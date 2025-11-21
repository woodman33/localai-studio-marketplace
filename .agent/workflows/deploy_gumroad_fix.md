---
description: Deploy Gumroad fixes to Hostinger VPS
---

# Deploy Gumroad Fixes to Hostinger VPS

Follow these steps to update your VPS with the latest Gumroad integration fixes.

## 1. Commit and Push Changes

First, we need to save your local changes and push them to the git repository so the VPS can pull them.

```bash
git add backend-chat.py .env.example walkthrough.md
git commit -m "Fix Gumroad Order ID lookup and update configuration"
git push origin main
```

## 2. SSH into VPS

Connect to your Hostinger VPS.

```bash
ssh root@31.220.109.75
```

## 3. Update Environment Variables

Once logged in, you need to add the Gumroad configuration to your `.env` file.

1.  Navigate to the project directory:

    ```bash
    cd /root/localai-studio-marketplace
    ```

2.  Edit the `.env` file:

    ```bash
    nano .env
    ```

3.  Add the following lines to the end of the file:

    ```bash
    # Gumroad Configuration
    GUMROAD_API_KEY=your_gumroad_api_key_here
    GUMROAD_PRODUCT_PERMALINK=udody
    ```

    _Replace `your_gumroad_api_key_here` with your actual Gumroad API Key._

4.  Save and exit (`Ctrl+O`, `Enter`, `Ctrl+X`).

## 4. Deploy Changes

Run the smart deployment script to pull the new code and rebuild the containers.

```bash
./SMART-DEPLOY.sh
```

## 5. Verify Deployment

After the script finishes:

1.  Visit [https://localai.studio](https://localai.studio)
2.  Try to activate Pro with a valid Order ID.
