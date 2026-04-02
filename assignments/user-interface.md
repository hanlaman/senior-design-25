# User Interface Specification

## Overview

The reMIND system includes two primary user interfaces:

1. **Patient Interface (Apple Watch App)**
2. **Caregiver Interface**

Both interfaces are designed with a strong emphasis on accessibility, simplicity, and real-time interaction, particularly for users with cognitive impairments such as dementia.

---

## 1. Patient Interface (Apple Watch App)

### Purpose

The Apple Watch app serves as the primary interaction point for individuals living with dementia. It enables users to communicate with the system using voice, receive contextual assistance, and remain connected to caregivers.

---

### Key Features

- Voice-first interaction (no typing required)
- Real-time AI-generated responses
- Minimal and intuitive interface
- Passive data collection (location, time context)
- Automatic alert triggering when needed

---

### Design Principles

The patient interface was designed using human-centered principles tailored to dementia users:

- **Simplicity**
  - Minimal UI elements to reduce confusion
  - Clear, single-action interactions

- **Error Tolerance**
  - Handles repeated or unclear inputs gracefully
  - No penalties for incorrect usage

- **Familiarity & Comfort**
  - Calm, reassuring voice responses
  - Option for familiar or personalized voice (future work)

- **Cognitive Accessibility**
  - Voice-first interaction reduces memory load
  - No reliance on navigation or menus

---

### Visual Design

- High-contrast color scheme for readability
- Large text and clear icons
- Consistent visual cues (e.g., alerts vs normal state)
- Avoidance of overly bright or saturated colors to prevent agitation

---

### Example Interaction Flow

1. User raises wrist and activates voice input  
2. User asks: “Where am I?”  
3. Voice input is sent to backend system  
4. Context (time, location) is processed  
5. AI generates and delivers a personalized response  
6. If abnormal behavior is detected → caregiver alert is triggered  

---

## 2. Caregiver Interface (Web Dashboard)

### Purpose

The caregiver dashboard provides real-time visibility into the patient’s status and allows caregivers to monitor safety, receive alerts, and interact with the system.

---

### Key Features

- Real-time alerts and notifications
- Patient status monitoring (location, activity)
- Two-way communication with patient system
- Reminder and message support

---

### Design Principles

- **Clarity**
  - Clear display of alerts and patient status
  - Prioritization of critical information

- **Responsiveness**
  - Real-time updates via WebSocket connection
  - Immediate alert visibility

- **Usability**
  - Simple layout for quick understanding
  - Minimal steps to access key information

---

### Example Caregiver Flow

1. Caregiver logs into dashboard  
2. Receives alert: “Patient may be disoriented”  
3. Views patient context (location, time, recent interaction)  
4. Takes action if necessary (call, check-in, etc.)  

---

## 3. Interaction Between Interfaces

The system connects both interfaces through a real-time pipeline:

- Watch captures user input  
- Backend processes and adds context  
- Cloud system generates response  
- Caregiver dashboard updates instantly if needed  

This ensures seamless communication between patient and caregiver.

---

## 4. Future UI Enhancements

- Voice personalization (family member voice simulation)
- Expanded caregiver analytics and insights
- Adaptive UI based on user behavior patterns
  
---
