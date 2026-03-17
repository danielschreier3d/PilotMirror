# PilotMirror Web App

Next.js + Tailwind CSS web app — identical to the iOS app, sharing the same Supabase backend.

## Setup

```bash
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

## Deploy to Vercel

1. Push the `web/` folder (or the full repo) to GitHub
2. Import into [vercel.com](https://vercel.com)
3. Set root directory to `web/`
4. Deploy — auto-deploys on every push

## Features

- ✅ Auth (invite code sign-up, email/password, forgot password)
- ✅ Assessment type + flight license setup
- ✅ Dashboard with 4-step progress cards
- ✅ Self-assessment survey
- ✅ Feedback link sharing (WhatsApp, Email, copy)
- ✅ AI analysis trigger + report view
- ✅ Respondent survey (public, no auth, `/feedback/[token]`)
- ✅ Interview simulation with AI hints
- ✅ Preparation guide / Tips
- ✅ Profile & settings
- ✅ Dark / Light / System theme
- ✅ PWA — "Add to Home Screen" on iPhone
- ✅ Fully bilingual (German / English, auto-detected from browser)
