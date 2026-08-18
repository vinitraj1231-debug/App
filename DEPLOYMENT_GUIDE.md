# Telegram Clone - Deployment, GitHub & APK Guide (हिंदी / Hinglish Guide)

Yeh guide aapko poora process batayegi ki kaise app aur backend ko GitHub par push karna hai, VPS (Ubuntu Server) par deploy karna hai, aur APK file build karke apne mobile me install karna hai.

---

## 🚀 1. GitHub Par Code Push Kaise Karein

### Step 1: Naya GitHub Repository Banayein
1. [GitHub](https://github.com) par jayein aur **New Repository** par click karein.
2. Repo ka naam rakhein (jaise: `telegram-clone-app`).
3. Repository ko **Public** ya **Private** select karein aur **Create repository** par click karein.

### Step 2: Apne Computer Par Terminal Se Code Push Karein
Terminal/Command Prompt me repository root folder me yeh commands chalayein:

```bash
# 1. Local Git repository initialize karein (agar nahi hai)
git init

# 2. Files ko stage karein
git add .

# 3. First commit karein
git commit -m "Initial commit: Telegram Clone Backend & Flutter Mobile App"

# 4. Main branch set karein
git branch -M main

# 5. Apne GitHub repo ka URL add karein
git remote add origin https://github.com/YOUR_GITHUB_USERNAME/telegram-clone-app.git

# 6. GitHub par code push karne ke liye terminal me run karein:
# git push -u origin main
```

---

## 🖥️ 2. VPS (Ubuntu Server) Par Backend Deploy Kaise Karein

Aap Kisi bhi VPS provider (Hostinger, DigitalOcean, AWS, Linode) ka Ubuntu Server use kar sakte hain.

### Method A: PM2 Ke Saath Deploy Karna (Simple & Direct)

#### Step 1: VPS Me SSH Se Login Karein
```bash
ssh root@YOUR_VPS_IP
```

#### Step 2: Node.js aur Git Install Karein
```bash
sudo apt update && sudo apt upgrade -y
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash -
sudo apt install -y nodejs git
```

#### Step 3: Project Clone Karein
```bash
git clone https://github.com/YOUR_GITHUB_USERNAME/telegram-clone-app.git
cd telegram-clone-app/backend
npm install
```

#### Step 4: PM2 Se Backend Ko 24/7 Live Karein
```bash
sudo npm install -g pm2
pm2 start server.js --name "telegram-backend"
pm2 save
pm2 startup
```

Aapka backend **`http://YOUR_VPS_IP:3000`** par live ho jayega!

---

### Method B: Docker Se Deploy Karna

VPS par Docker install karein:
```bash
sudo apt install -y docker.io docker-compose
cd telegram-clone-app/backend
sudo docker-compose up -d --build
```

---

## 📱 3. Mobile APK Kaise Milega / Build Hoga

Flutter APK aap 2 aasan tariko se bana sakte hain:

### Method 1: Apne PC Par Flutter Se APK Build Karna (Recommended)

1. `mobile_app/lib/services/api_service.dart` file kholein.
2. `baseUrl` ko apne VPS IP se replace karein:
   ```dart
   static String baseUrl = 'http://YOUR_VPS_IP:3000'; // Replace with your VPS IP
   ```
3. Terminal me `mobile_app` directory me jayein aur command chalayein:
   ```bash
   cd mobile_app
   flutter build apk --release
   ```
4. Build hone ke baad aapka APK file is location par milega:
   ```text
   mobile_app/build/app/outputs/flutter-apk/app-release.apk
   ```
5. Is `app-release.apk` file ko apne phone me transfer karke install kar sakte hain!

---

### Method 2: GitHub Actions (Automatic APK Generator on GitHub)

Aap GitHub par code push karenge aur GitHub khud hi APK build karke aapko download link de dega!

1. Apne repository me yeh file banayein: `.github/workflows/build_apk.yml`
2. Workflow configuration:
```yaml
name: Build Flutter APK

on:
  push:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Set up Java
        uses: actions/setup-java@v3
        with:
          distribution: 'zulu'
          java-version: '17'

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.19.x'

      - name: Install Dependencies
        run: |
          cd mobile_app
          flutter pub get

      - name: Build APK
        run: |
          cd mobile_app
          flutter build apk --release

      - name: Upload APK Artifact
        uses: actions/upload-artifact@v3
        with:
          name: telegram-clone-apk
          path: mobile_app/build/app/outputs/flutter-apk/app-release.apk
```
3. Ab jab bhi aap GitHub par code push karenge, **Actions** tab me jaker tayyar **APK File download** kar sakte hain.

---

## 🔒 4. App Security & Offline Features Explanation

1. **Offline Mode & Offline UI**:
   - Bina internet ke app me **"Offline Mode"** banner aayega.
   - Internet na hone par bhi aapke purane sabhi chats aur messages local SQLite database (`sqflite`) se turant dikhenge.

2. **Offline Messages Queueing (Net On / Off Logic)**:
   - Jab aap offline me kisi ko message bhejenge, toh message bhejte hi screen par **Clock icon (⌛)** aayega aur message local queue me save ho jayega.
   - **Bina internet ke message server par ya doosre user tak bilkul nahi jayega.**
   - Jaise hi net reconnect hoga, app automatically background me queued messages ko server par send karke delivery status update kar degi!

3. **Notification Permissions**:
   - App open hone par `permission_handler` aur `flutter_local_notifications` ke zariye permission mangegi.
   - Jaise hi samne wala user message bhejega, real-time popup notification alert aayega.

4. **Security**:
   - Password encryption ke liye `bcryptjs` (salt hashing) ka use hua hai.
   - Authentication ke liye JWT Tokens (30 days expiry) use kiye gaye hain.
