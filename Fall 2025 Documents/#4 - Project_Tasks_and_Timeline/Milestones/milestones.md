## Milestones List

| **Milestone** | **Description / Deliverable** |
|----------------|--------------------------------|
| **1. Project Kickoff & Requirements Consolidation** | Confirm all user stories, design constraints, and success criteria. **Deliverable:** Finalized requirements document and initial feature backlog. |
| **2. System Architecture & Data Flow Design** | Complete all design diagrams (D0–D2) defining data flow between wearable device, backend APIs, and caregiver app. **Deliverable:** Finalized system architecture and module integration diagram. |
| **3. Database Architecture Design** | Create and document database schemas for user profiles, memory entries, and logs. Include object storage for images/audio and caching mechanisms for frequent queries. **Deliverable:** Relational schema diagrams and DB implementation plan. |
| **4. Tech Stack Definition** | Choose all technologies and tools for front-end, back-end, database, and AI components. **Deliverable:** Tech stack summary document (languages, APIs, frameworks, hosting solutions). |
| **5. “Memory” Storage and Recollection** | Implement the end-to-end pipeline to record, transcribe, and store user memories, then retrieve them upon request. **Deliverable:** Working demo showing accurate memory recall via conversation interface. |
| **6. Front-End: Phone App – Patient Portal** | Build patient-facing mobile interface with conversational AI, limited monitoring display, and push notification reception. **Deliverable:** Functional prototype app. |
| **7. Front-End: Phone App – Caregiver Portal** | Develop caregiver-facing interface with statistical history, alert notifications, and device monitoring. **Deliverable:** Caregiver app with dashboard and alert system. |
| **8. Device (Bluetooth Wearable) Prototype** | Design and build wearable button device capable of capturing audio, transmitting input, and optionally monitoring health or fall events. **Deliverable:** Functional prototype with Bluetooth connectivity. |
| **9. Back-End APIs** | Implement core APIs (Conversation API, Monitoring API, Alert/Notification API) to manage communication between wearable, mobile app, and cloud database. **Deliverable:** Deployed backend with documentation. |
| **10. Final System Integration & Testing** | Conduct full end-to-end testing across all modules. Verify voice transcription, data storage, caregiver alerts, and device monitoring. **Deliverable:** Integrated system demo and final project report. |

---
- Project kickoff + requirements consolidation
- System architecture + data flow design (design diagrams)
- Database architecture
  - Design database tables and relationships with each, object storage for things such as images or documents, and any necessary caching mechanisms.

- 'Memory' storage and recollection.
- Define tech stack

### Front End:
- #### Phone App
 - Patient Portal
   - conversational interface
   - monitoring (limited)
 - Caregiver Portal
   - statistic (historical)
   - receive notification alerts
   - push notification
   - device monitoring
- #### Device (Bluetooth)
  - Conversational Interface
    - voice transcription
    - sound recognition (tone/yells/cries)
  - Monitoring
    - optional: text-to-speech
    - health monitoring
    - fall detection

### Back End
----------------------------------------------------------------------------------------------->

#### conversational interface ----> transcription, sound classification, opt. audio file ----> conversation API
#### conversational interface < ---- response text/voice* (*TBD)  <---- conversation API
#### monitoring (limited) ----> monitoring events ----> monitoring API
#### statistic (historical) <---- request/response <---- monitoring API
#### receive notification alerts <---- alerts <---- monitoring API
#### push notification to patient <---- reminders <---- monitoring API

<-----------------------------------------------------------------------------------------------
