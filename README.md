# 🛠️ Recovery Pro v2.0 | Advanced File Recovery System

![Language](https://img.shields.io/badge/Language-x86_Assembly-blue.svg?style=for-the-badge&logo=assemblyscript)
![Assembler](https://img.shields.io/badge/Assembler-MASM32-orange.svg?style=for-the-badge)
![Platform](https://img.shields.io/badge/Platform-Windows-0078D6?style=for-the-badge&logo=windows)

**Recovery Pro** is a high-performance, low-level utility engineered to recover deleted data directly from storage volumes. By bypassing file system abstractions, it performs **Raw Sector Analysis** and **File Carving** to restore lost information.

---

## 👥 The Team
* **M. Jamal Ahmad Khan** – [GitHub Profile](https://github.com/MJamalAhmadKhan)
* **Bilal Ahmad Khan** – Project Collaborator

## 🎓 Academic Context
This project was developed as a semester finale for the **Computer Organization and Assembly Language (COAL)** course at **Namal University, Mianwali**, under the expert guidance of **Sir Abdul Rafay**.

---

## ⚙️ How It Works: The Logic
The system treats the target drive as a raw byte stream. It implements a **Rolling Buffer Strategy** to scan for unique hexadecimal signatures (Magic Numbers) at the sector level.



### **Signatures Supported:**
| File Type | Hex Header (Magic Number) |
| :--- | :--- |
| **JPEG** | `FF D8 FF` |
| **PNG** | `89 50 4E 47` |
| **PDF** | `25 50 44 46` |
| **ZIP/Office** | `50 4B 03 04` |
| **RAR** | `52 61 72 21` |

---

## 🚀 Key Features
* **Administrative Volume Access:** Requests `SeManageVolumePrivilege` for deep hardware interaction.
* **Direct Disk I/O:** Communicates with `\\.\PhysicalDrive` using Win32 API (`CreateFile`, `ReadFile`).
* **Native GUI:** A lightweight, responsive interface built entirely with the Windows API.
* **Smart Identification:** Logic to distinguish between standard ZIP archives and OpenXML documents (DOCX/XLSX).

---

## 🛠️ Technical Implementation
- **Instruction Set:** x86 (32-bit)
- **Registers:** Optimized usage of `ESI` for buffer navigation and `EDI` for pattern matching.
- **Memory:** Managed via a 4MB dynamic rolling buffer using `GlobalAlloc`.
- **Logic:** Implements file header/footer verification to calculate actual file sizes during extraction.

---

## 🖥️ Getting Started
1. **Clone the repository.**
2. **Build:** Use the MASM32 `ml` and `link` tools.
3. **Run as Admin:** **Required.** Right-click the `.exe` and select "Run as Administrator" to grant the program permission to access raw disk sectors.

---

## 📜 License
*Academic project intended for educational and research purposes only.*
