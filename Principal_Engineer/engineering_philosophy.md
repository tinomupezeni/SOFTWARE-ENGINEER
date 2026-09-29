# Engineering Philosophy — How the Best Build Websites

This document captures the mindset and principles that elite software engineers follow when building web projects. Refer back to this throughout the UNESCO project.

---

## 1. Start with the Problem, Not the Code

- **Who is this for?** (users, not stakeholders)
- **What job does this site do?** (inform, convert, engage?)
- **What's the single most important action?** (the one thing that matters most)

Example: *"Does UNESCO Harare need a website, or do they need a way for researchers to find country data quickly?"* — framing changes everything.

---

## 2. Design for Failure

- What happens when the CDN goes down?
- What if the user has no JavaScript?
- What if the database is slow?
- What if content editors make mistakes?

Build **resilience in**, not as an afterthought.

---

## 3. Simplicity as a Feature

- Fewer features, done well
- Every page has one purpose
- Navigation should be obvious without thinking
- If you need a manual, the design failed

> *"Perfection is achieved not when there is nothing more to add, but when there is nothing left to take away."* — Antoine de Saint-Exupéry

---

## 4. Performance is a Feature

- **3-second rule**: Users leave after 3 seconds
- Core Web Vitals matter (LCP, FID, CLS)
- Every image, font, and script is a cost
- Measure first, then optimize — not guess

---

## 5. Content-First Design

- Design with real content, not lorem ipsum
- Content hierarchy drives layout, not the reverse
- Mobile-first forces you to prioritize
- If content doesn't fit, the content is wrong — not the layout

---

## 6. Consistency > Novelty

- Design systems, not pages
- Components that compose, not unique snowflakes
- Consistent patterns reduce cognitive load
- Users shouldn't have to relearn your site on each page

---

## 7. Accessibility is Not Optional

- Semantic HTML first
- Keyboard navigable
- Screen reader tested
- Color contrast ratios met
- Not a feature — a requirement

---

## 8. Ship, Then Iterate

- Perfect is the enemy of live
- MVP means **minimum viable** — not minimum
- Real user feedback > opinions in meetings
- Deploy early, deploy often

---

## 9. Technical Decisions Are Product Decisions

- Choosing Laravel isn't just technical — it affects hiring, speed, ecosystem
- Database choice affects what queries are fast
- Hosting affects reliability and cost
- Every technical choice constrains future product choices

---

## 10. Documentation is a Deliverable

- Not just code comments
- Decision logs: **why** you chose X over Y
- Onboarding should take hours, not weeks
- If you can't explain it simply, you don't understand it

---

## The Common Thread

Elite engineers think in **systems, not features**. They see the website as a living product with users, constraints, and goals — not a collection of pages to build.
