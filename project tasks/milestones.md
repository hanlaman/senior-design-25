## Milestones List:
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
conversational interface ----> transcription, sound classification, opt. audio file ----> conversation API
conversational interface < ---- response text/voice* (*TBD)  <---- conversation API
monitoring (limited) ----> monitoring events ----> monitoring API
statistic (historical) <---- request/response <---- monitoring API
receive notification alerts <---- alerts <---- monitoring API
push notification to patient <---- reminders <---- monitoring API


<-----------------------------------------------------------------------------------------------
