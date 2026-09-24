# **Architectural Composition, Frontend Systems, and Design Mechanics of Luma**

The digital event platform Luma (lu.ma) has emerged as a benchmark for high-polish user interface design and responsive software engineering in the consumer and prosumer web space1. Founded in 2020 by Victor Pontis and Danqing Liu—a former product designer at YouTube and Uber—the platform originated from a focused use case: enabling independent organizers to coordinate and monetize virtual events during the pandemic without the administrative friction of legacy enterprise software1. Over time, it has evolved into a comprehensive platform powering in-person gatherings, conferences, social calendars, and digital communities worldwide1.

Luma’s reputation for interface quality is frequently attributed to aesthetic minimalism, but the user experience is fundamentally driven by deliberate technical architecture1. The engineering team adopted a disciplined systems philosophy: eliminating heavy runtime abstractions, rejecting monolithic object-relational mapping layers, enforcing strict sub-second performance budgets on backend routes, and maintaining dedicated native client codebases rather than generic web wrappers3.

## **Comprehensive Technical Stack Inventory**

The technological infrastructure behind Luma spans a distributed browser, mobile, server, and persistence ecosystem configured for horizontal scaling, rapid continuous deployment, and visual rendering precision3.

&nbsp;

| Layer | Technologies Selected | Alternatives Evaluated or Replaced | Key Architectural Drivers |
| :---- | :---- | :---- | :---- |
| **Web Presentation** | React, Next.js, styled-jsx \+ SCSS, Format.JS (react-intl)3 | Pure CSS Modules, Emotion, react-i18next \[cite: 3, 6\] | Server-side rendering (SSR) for zero-latency initial paints; co-located component styling without multi-file drift; zero-global state localization3. |
| **Mobile Clients** | Native iOS (Swift & SwiftUI), Native Android (Kotlin)6 | React Native, Flutter6 | Deterministic 120 Hz ProMotion animation curves; zero bridge serialization; native OS haptics and system string catalog integration6. |
| **Backend & Application APIs** | Node.js, TypeScript, Koa web framework3 | Express.js, Ruby on Rails, NestJS3 | End-to-end type safety between client and server; native asynchronous middleware primitives; predictable sub-second JSON response budgets3. |
| **Data Persistence** | AWS Aurora (PostgreSQL), Knex.js \+ Raw SQL3 | MySQL, Prisma, TypeORM, ActiveRecord3 | Separation of compute and storage; fine-grained index optimization via hand-tuned SQL; flexible schema attributes utilizing native PostgreSQL JSONB3. |
| **Realtime Engine** | Centrifugo (Go-based WebSocket service)3 | In-process Node.js WebSockets, Socket.io3 | Complete offloading of persistent TCP connections from API compute; high-throughput pub/sub for attendee counters and live chat3. |
| **Media & Background Processing** | Puppeteer (Headless Chromium), Redis Queue \+ Workers3 | Monolithic API image generation, ImageMagick3 | Isolation of memory-intensive Open Graph banner and ticket rasterization into a dedicated, crash-tolerant container environment3. |
| **Cloud Hosting & Delivery** | AWS ECS (Fargate), Vercel (Edge Previews)3 | Render, Heroku3 | High-availability container orchestration, fine-grained VPC security groups, and automated preview environments per Git pull request3. |
| **Telemetry & Observability** | Honeycomb, Sentry3 | Datadog, standard ELK stack3 | Canonical logging and distributed trace analysis through Koa middleware; client-side and server-side runtime error tracking3. |

## **Frontend Web Architecture and Rendering Dynamics**

Luma’s web client is designed to bridge the gap between static web delivery speeds and dynamic single-page application interactivity3. Rather than leaning on heavyweight third-party component libraries that introduce cascading runtime styles and layout shifts, the platform relies on a custom design system combined with Next.js and React3.

The selection of Next.js provides the compilation and asset orchestration pipeline required to maintain minimal bundle sizes3. Next.js automatically executes route-based code splitting, dynamic prefetching of linked resources, and hybrid server-side rendering3. Server rendering ensures that initial HTML documents arrive at the browser pre-populated with event metadata, dates, and host information, driving low First Contentful Paint (FCP) metrics and robust search engine indexing3. Once the DOM is established, React hydrates the view smoothly, turning the interface into a client-rendered environment where subsequent view transitions, calendar manipulations, and modal popups execute without full-page reloads3.

Styling ergonomics were solved by moving away from traditional CSS Modules to a co-located approach utilizing styled-jsx enhanced with SCSS compilation3. During early platform iterations, the team identified operational drag associated with CSS Modules: every minor component refactor or file migration required synchronizing both a JavaScript file and an external stylesheet3. By adopting styled-jsx, style definitions are encapsulated directly within the component file while maintaining full SCSS capabilities, including nested selectors, mathematical color manipulations, and reusable design token variables3. To accelerate baseline development without compromising uniqueness, the frontend selectively incorporates standard utility classes from Bootstrap for spacing and flexbox alignment, while all core interaction components—such as floating action menus, ticket drawers, and hero banners—are authored natively from scratch3.

Performance at the typography layer is achieved by deliberately omitting custom, remote web fonts9. Web applications frequently suffer from layout shifts (Cumulative Layout Shift) or flashes of unstyled content (FOUT) while external WOFF2 font files are negotiated over HTTP. Luma circumvents this by relying on a native operating system font cascade:

\-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Inter, "Helvetica Neue", Arial, "Noto Sans", sans-serif

\[cite: 9\]

This rule directs the client device to render text using its own low-level system typeface—San Francisco on Apple hardware, Segoe UI on Windows, and Roboto on Android9. As a result, typography renders instantly on the initial frame, draws upon hardware-accelerated OS rasterization routines, and feels completely native to whichever platform the user is operating9.

## **Mobile Engineering: Native Client Execution**

In an industry where cross-platform frameworks such as React Native and Flutter are widely adopted for operational economy, Luma diverged by engineering fully native client applications: Swift and SwiftUI for iOS, and Kotlin for Android (com.luma.mobile)6.

&nbsp;

&nbsp;

&nbsp;

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\+---------------------------------------+  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;|         Central Cloud Engine          |  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;|  AWS ECS / Aurora Postgres / Redis    |  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\+-------------------+-------------------+  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;|  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;REST APIs / JSON  |  Centrifugo WebSockets  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;v  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\+----------------------------+---------------------------+  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;|                                                        |  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;v                                                        v  
\+-----------------------+                                \+-----------------------+  
|    Web Application    |                                |   Native Mobile App   |  
|-----------------------|                                |-----------------------|  
| • React / Next.js     |                                | • Swift & SwiftUI     |  
| • styled-jsx \+ SCSS   |                                | • Kotlin (Android)    |  
| • Format.JS (\<T /\>)   |                                | • Native String Catalogs|  
| • CSS Container Rules |                                | • CoreHaptics Engine  |  
\+-----------------------+                                \+-----------------------+

The perceived smoothness of mobile software is directly tied to frame-rate consistency and touch event latency. Cross-platform architectures frequently encounter frame drops during heavy UI transformations because user gestures and animations must cross a serialization bridge between the JavaScript runtime and native platform view hierarchies10. By constructing the iOS app natively in SwiftUI, Luma interfaces directly with Apple's Core Animation and Metal graphical pipelines6. Complex continuous interactions—such as pulling down dynamic event sheet drawers, transitioning between calendar day views, or navigating interactive guest maps—render deterministically at 120 frames per second on ProMotion displays.

Furthermore, SwiftUI’s declarative paradigms mirror React’s state-driven UI paradigm, allowing the team’s mental model of unidirectional data flow to translate across platforms without sacrificing low-level hardware access6. Native engineering also unlocked deep platform integration: the iOS application leverages native String Catalogs (.xcstrings), system-level haptic generators via UIImpactFeedbackGenerator for physical confirmation upon event registration, and low-overhead Apple Wallet pass rendering5. On Android, the native Kotlin codebase interfaces directly with Android platform services, Google Wallet APIs, and native hardware camera pipelines to guarantee instant QR code scanning during on-site event check-in workflows5.

## **Advanced CSS Mechanics and Visual Polishing Techniques**

The distinctive visual polish of Luma’s interface is rooted in advanced CSS layout and rendering features championed by co-founder Danqing Liu4. By leveraging emerging CSS specifications, the engineering team avoided complex JavaScript layout calculations that often introduce visual stutter and main-thread blocking12.

&nbsp;

| Modern CSS Technique | Implementation Mechanism | Functional and Aesthetic Value |
| :---- | :---- | :---- |
| **CSS Container Queries** | container-type: inline-size paired with @container breakpoints12. | Allows event cards and modular widgets to reorganize dynamically based on their local container's width rather than the global viewport width12. |
| **Dynamic Viewport Units** | Sizing hero containers and mobile sheets using 100dvh and 100dvw12. | Prevents sudden visual jumping and clipping on mobile browsers when software address bars dynamically expand or collapse during scroll12. |
| **Responsive Grid Mathematics** | grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)) combined with gap12. | Generates intrinsically fluid layouts for attendee listings and theme pickers without requiring negative margin hacks or media queries12. |
| **Declarative Form States** | State styling using :focus-within, :invalid, and :out-of-range12. | Offloads visual form feedback directly to the browser layout engine, keeping input wrappers visually reactive without running JS event listeners12. |
| **GPU-Layered Translucency** | backdrop-filter: blur(20px) saturate(180%) over alpha-blended surfaces12. | Produces layered frosted-glass depth on navigation headers and modals, maintaining high frame rates via hardware-accelerated compositor passes12. |

Container queries serve as a foundational mechanism for Luma’s responsive modularity12. Traditional responsive design relies exclusively on viewport-based media queries, which fail when an identical component needs to live simultaneously in a narrow sidebar, an expandable modal, or a full-width feed12. By declaring container-type: inline-size on wrapping elements, an event card inspects its immediate boundary box: if allocated wider space, it automatically arranges its cover image, date column, and action buttons horizontally; when confined to a narrow column, it reflows the image to the top and collapses details vertically12. This layout reorganization executes strictly within the browser's native layout engine with zero JavaScript recalculation overhead12.

Dynamic viewport units (100dvh) resolve an issue native to modern mobile browsers, where scrolling triggers the browser chrome to retract, abruptly altering the measurable height of standard 100vh viewports12. Sizing full-height registration drawers and mobile hero containers using dynamic viewport units ensures that interfaces remain locked to the true visible screen height, preserving layout continuity12.

Visual hierarchy is further enhanced through hardware-accelerated compositing12. Floating navigation bars, modal dialogs, and slide-over drawers utilize backdrop-filter: blur(...) combined with subtle saturation boosts12. When properly layered, these filters allow underlying text and dynamic cover artwork to remain subtly visible beneath frosted overlays, communicating depth and spatial context reminiscent of macOS and iOS interface paradigms12.

## **Backend Infrastructure, Persistence, and Real-Time Topology**

The server architecture behind Luma prioritizes speed, transactional reliability, and architectural minimalism over complex, distributed microservice meshes3. Services are strictly segmented according to their operational resource consumption and latency characteristics3.

&nbsp;

&nbsp;

&nbsp;

\+-------------------------------------------------------------+  
|               GitHub Actions Waterfall Deploy               |  
|                                                             |  
|   Step 1: Execute Database Migrations (AWS Aurora)          |  
|         │                                                   |  
|         ▼                                                   |  
|   Step 2: Roll out Container Update to API Service (Koa)    |  
|         │                                                   |  
|         ▼                                                   |  
|   Step 3: Deploy Frontend Web Services (Next.js / SSR)      |  
\+-------------------------------------------------------------+

### **The Node.js and Koa Foundation**

Luma’s primary backend services are authored in TypeScript and hosted within the **Koa** web framework3. The selection of Koa over Express was driven by Koa’s early, native integration of asynchronous primitives (async/await), which prevents unhandled promise errors and provides an elegant middleware execution onion3. The engineering team operates under a strict operational performance budget: every primary API endpoint must return a structured JSON response in under one second3. Operations with processing profiles exceeding this threshold are dispatched to asynchronous background job queues, ensuring that API threads are never blocked by heavy computational tasks3.

### **Persistence Strategy: PostgreSQL and Hand-Crafted SQL**

Luma relies on PostgreSQL managed via **AWS Aurora** as its central relational datastore3. Aurora’s architectural model—which decouples the compute layer from the distributed storage plane—allows the database to scale storage automatically, execute continuous background backups, and support point-in-time rollbacks without administrative downtime3.

In contrast to the contemporary industry trend of relying on heavy JavaScript ORMs like Prisma or TypeORM, Luma chose to combine **Knex.js with Raw SQL**3. The engineering team determined that as a schema grows in complexity, ORMs introduce significant overhead: they obscure query execution plans, generate expensive multi-table joins, and struggle with memory efficiency during high-concurrency spikes3. Knex.js provides a flexible query-building interface, but when complex data aggregation is required, engineers write raw, optimized SQL queries directly3.

Data modeling within PostgreSQL is augmented by two specific design choices:

> 1. **Prefixed Unique Identifiers**: Rather than using bare auto-incrementing integers or standard UUIDs, Luma uses database functions to generate human-readable, prefixed identifiers (such as usr\_, evt\_, and tkt\_), similar to the pattern popularized by Stripe3. This simplifies debugging, distributed tracing, and foreign key verification across systems3.  
> 2. **Hybrid Relational-Document Architecture via JSONB**: Dynamic event configurations—such as custom host question forms, arbitrary ticket tier rules, and aesthetic theme settings—are stored within PostgreSQL JSONB columns3. This combines the strict transactional integrity and ACID guarantees of a relational database with the dynamic schema agility typically associated with document stores3.

### **Realtime State and Service Isolation**

Real-time interaction is decoupled from the main HTTP API using **Centrifugo**, a specialized, high-performance real-time messaging server written in Go3. Managing thousands of persistent, stateful WebSocket connections directly within a Node.js process threatens to saturate the single-threaded event loop and exhaust memory buffers3. By utilizing Centrifugo as an independent service, client connections (web and mobile) remain connected to Centrifugo instances3. When state mutations occur—such as an event reaching capacity, an attendee checking in, or a new message arriving in the host chat—the Node.js API publishes an event to Centrifugo, which broadcasts the payload across relevant WebSocket channels within milliseconds3.

Media processing and dynamic social banner generation are similarly isolated into a dedicated **Puppeteer** container service3. Generating Open Graph preview images and digital ticket passes requires launching Headless Chrome instances to rasterize HTML/CSS layouts into images3. Because headless browser automation is inherently memory-intensive and susceptible to process-level crashes, running Puppeteer inside the core API would introduce severe systemic risk3. Isolating Puppeteer into its own container ensures that any memory spike or rendering failure remains sandboxed, preserving uninterrupted core booking and ticketing services3.

## **Continuous Deployment, Cloud Infrastructure, and Observability**

Luma’s production infrastructure runs primarily on **Amazon Web Services (AWS)** using **AWS ECS with AWS Fargate** to manage container lifecycles3. Fargate abstracts underlying virtual server administration, spinning container tasks up and down elastically based on inbound request traffic3.

While AWS hosts the core production APIs, databases, and background workers, **Vercel** is retained specifically to provide edge-hosted preview environments for every opened GitHub Pull Request3. This bifurcated infrastructure allows frontend designers and engineers to interact with live interface changes in isolated staging sandboxes before code is merged into the mainline branch3.

&nbsp;

&nbsp;

&nbsp;

\+-----------------------------------------------------------------------------------+  
|                        Luma Production & CI Pipeline                              |  
\+-------------------+-------------------------------+-------------------------------+  
| Stage             | Technology                    | Operational Role              |  
\+-------------------+-------------------------------+-------------------------------+  
| Code Integration  | GitHub Actions                | Static analysis, type-checks, |  
|                   |                               | and automated test suites     |  
| Preview Sandbox   | Vercel                        | Edge deployments generated    |  
|                   |                               | for PR visual review          |  
| Deployment Order  | Waterfall Script              | 1\. DB Migration               |  
|                   |                               | 2\. API Container Rollout      |  
|                   |                               | 3\. Web Service Propagation    |  
| Production Run    | AWS ECS / Fargate             | Scalable container tasks      |  
| Observability     | Honeycomb                     | Distributed route tracing via |  
|                   |                               | custom Koa middleware         |  
| Error Monitoring  | Sentry                        | Client/server exception       |  
|                   |                               | capture and tracking          |  
\+-------------------+-------------------------------+-------------------------------+

The engineering pipeline emphasizes continuous delivery, deploying updates to production more than ten times per day3. Deployments execute via GitHub Actions through a strict **waterfall deployment model** to prevent schema mismatches and client errors3:

First, automated database migrations run against the AWS Aurora cluster3. Second, new API container tasks are deployed across AWS ECS, ensuring that backend endpoints are fully capable of serving both legacy and newly requested fields3. Third, the Next.js web service containers are updated, exposing the new user-facing functionality3. By enforcing this sequential pipeline, Luma eliminates race conditions where newly deployed frontend assets attempt to communicate with an unmigrated database or an outdated API service3.

Full-stack observability is managed through a pairing of **Honeycomb** and **Sentry**3. A custom Koa middleware wraps all inbound API requests, synthesizing operational metrics into canonical log structures dispatched to Honeycomb3. This enables real-time distributed tracing, giving engineers granular visibility into database query durations, third-party API latency (such as Stripe or Zoom), and traffic spikes3. Sentry runs continuously across both the web browser client, native mobile runtimes, and backend containers, capturing uncaught exceptions and indexing stack traces against exact release tags3.

## **Unified Multi-Platform Localization Engine**

A major operational challenge for modern platforms is delivering an interface that feels instantly localized across global markets without imposing ongoing engineering friction6. Luma developed an automated localization pipeline capable of translating both web and mobile experiences into more than 40 languages6.

On the web and backend, the platform standardized on **Format.JS (react-intl)**, chosen because it operates cleanly without global state dependencies6. To prevent verbosity within the codebase, custom component aliases were introduced: \<T /\> wraps \<FormattedMessage /\>, and the function t(...) encapsulates formatMessage(...)6.

To completely eliminate the friction of creating and organizing semantic translation keys (such as common.auth.welcome\_button\_label), the team engineered a custom **ESLint plugin** that generates a deterministic hash ID on file save6:

![][image1]

Whenever a developer writes or edits text in English alongside an explanatory context description, the linter recalculates the hash automatically6. If the English copy changes, a new hash is produced, signaling that new translations are required while falling back smoothly to the English default in the interim6.

The pipeline cleanly resolves the architectural differences between web React and native iOS6. While the web requires FormatJS-compatible JSON files adhering to the ICU message format (such as complex bracketed pluralizations), iOS requires Apple's native .xcstrings string catalogs, which key strings directly by their English values rather than generated hashes6. Luma bridged this divergence using an automated, nightly AI translation pipeline6:

> 1. Extraction scripts sweep the React codebase using the FormatJS CLI to capture missing hash IDs, while Xcode automatically compiles updated string parameters into .xcstrings catalogs6.  
> 2. A centralized script batches untranslated strings and dispatches them to large language models, providing structured context: a base brand prompt governing Luma’s conversational tone, project-specific formatting instructions (enforcing ICU syntax for web and stringdict syntax for iOS), and language-specific glossaries6.  
> 3. The pipeline generates automated GitHub Pull Requests containing updated localization dictionaries for both codebases simultaneously6.  
> 4. On the backend, a shared helper function, getT(locale), accesses the same dictionaries to translate dynamic server-generated communications—such as transactional confirmation emails, calendar invite attachments, and WhatsApp reminders—ensuring consistent tone across all client touchpoints6.

## **Product Craft, Micro-Interactions, and Engineering Synthesis**

The final layer contributing to Luma’s polished feel is the tight integration between design intuition and software implementation4. Co-founder Danqing Liu’s dual capability as an active software engineer and seasoned product designer eliminates the translational losses that typically occur between visual Figma concepts and final code delivery4. Daily design synchronizations between the founders ensure that functional edge cases are solved directly at the code level rather than compromised during handoff3.

This culture produces several signature micro-interaction patterns that define the product experience:

* **Zero-Latency Optimistic UI**: When a user registers for an event, saves a calendar, or changes an RSVP status, the frontend updates the visual interface immediately3. The application does not freeze behind loading spinners; it assumes operational success, dispatches the HTTP mutation to the Koa API in the background, and relies on Centrifugo WebSocket broadcasts to reconcile backend truth3.  
* **Optical Alignment Over Strict Math**: Interface typography and iconography are positioned according to visual weight rather than rigid mathematical centers, utilizing carefully tuned line heights, subtle letter-spacing adjustments, and balanced margins to deliver an organic aesthetic4.  
* **Tactile Haptic Integration**: On native mobile devices, user confirmations—such as ticket check-in scans, successful payment transfers, or bookmarking an event—fire finely tuned system haptic patterns, pairing visual transformations with physical confirmation5.  
* **GPU-Accelerated Transitions**: All floating drawers, sliding modals, and card zoom states operate exclusively on CSS properties that run on the GPU compositor layer (transform, opacity, and filter), avoiding CPU-bound layout recalculations and guaranteeing smooth animation pacing under all device conditions12.

Luma demonstrates that producing an elite digital product does not require obscure, overly complex frameworks. Instead, it is the result of architectural discipline: leveraging proven, battle-tested tools like Next.js, Node.js, and PostgreSQL; embracing native development on mobile platforms; utilizing modern browser standards like container queries and dynamic viewport units; and maintaining an obsessive focus on performance budgets and visual craftsmanship across the entire engineering lifecycle3.

#### **Works cited**

> 1. 7 Best Cvent Alternatives for Event Management In 2026, [https://blog.promotix.com/cvent-alternatives](https://blog.promotix.com/cvent-alternatives)  
> 2. Victor Pontis \- LinkedIn, Twitter, Facebook \- Mesh, [https://me.sh/profile/victor-pontis](https://me.sh/profile/victor-pontis)  
> 3. Luma's Tech Stack \- Victor Pontis, [https://luma.com/p/zPamspcICt0f3q9/Lumas-Tech-Stack](https://luma.com/p/zPamspcICt0f3q9/Lumas-Tech-Stack)  
> 4. Dan Liu, [https://danliu.xyz/](https://danliu.xyz/)  
> 5. Luma: Events & Invites \- Apps on Google Play, [https://play.google.com/store/apps/details?id=com.luma.mobile](https://play.google.com/store/apps/details?id=com.luma.mobile)  
> 6. Translating our website and app into 40 languages using AI, [https://pont.is/p/translating-luma](https://pont.is/p/translating-luma)  
> 7. Luma: Events & Invites \- Apps on Google Play, [https://play.google.com/store/apps/details?id=com.luma.mobile\&hl=en](https://play.google.com/store/apps/details?id=com.luma.mobile&hl=en)  
> 8. \[BUG\] \[P1\] Unable to resume activity crash during payment · Issue, [https://github.com/stripe/stripe-android/issues/13041](https://github.com/stripe/stripe-android/issues/13041)  
> 9. What Font Does lu.ma Use? Live Typography Check, [https://www.sitefontcheck.com/fontsusedby/lu.ma](https://www.sitefontcheck.com/fontsusedby/lu.ma)  
> 10. react-native-calendar-list CDN by jsDelivr \- A CDN for npm and GitHub, [https://www.jsdelivr.com/package/npm/react-native-calendar-list](https://www.jsdelivr.com/package/npm/react-native-calendar-list)  
> 11. TypeScript-Go Performance Issue in ci (github action) \#1507, [https://github.com/microsoft/typescript-go/issues/1507](https://github.com/microsoft/typescript-go/issues/1507)  
> 12. 5 Under-Utilized CSS Rules to Elevate Your Design \- Dan Liu, [https://danliu.xyz/post/css-rules](https://danliu.xyz/post/css-rules)  
> 13. Deep Research Report on Luma Platform and Its Founder Victor, [https://www.ababnews.com/depth/luma-victor-pontis](https://www.ababnews.com/depth/luma-victor-pontis)

[image1]: <data:image/png;base64,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>