# Bug Report: Data Intelligence Studio Bypasses Dashboard Layout
**Project:** TESC
**Date:** 2026-10-09
**Description:** The `DataIntelligenceStudio.tsx` React component was built using raw HTML (`div className="flex h-screen"`) and raw tailwind classes without wrapping itself in the standard `<DashboardLayout>` shell. This caused the main application sidebar and header to disappear, completely disconnecting the page from the system's Shadcn UI design system.
**Resolution:** Refactored `DataIntelligenceStudio.tsx` to return `<DashboardLayout>`, and replaced all raw HTML form elements and tables with standardized Shadcn UI components (`Card`, `Button`, `Input`, `Table`) to match the global UI aesthetic and dark mode compatibility.
**Resolved By:** Antigravity
