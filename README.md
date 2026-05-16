Development of PMU Data Analysis Methods for Sub-Oscillation DetectionThis repository contains the technical report and MATLAB algorithms developed during my 300-hour research internship at INRIM (National Institute of Metrological Research), Italy. 

📌 Project Overview
The project focused on the performance evaluation of Phasor Measurement Units (PMUs) and the development of signal-processing methods to detect sub-oscillation phenomena in modern power grids. This work is part of the European Metrology Project 24DIT05 GridData.  
Key Objectives:Performance Evaluation: Analyzing TVE (Total Vector Error) and ROCOF under steady-state and dynamic conditions.  Algorithm Development: Designing a MATLAB-based sliding-window workflow for dominant frequency extraction from PMU output channels.  
Comparative Analysis: Comparing developed algorithms with reference methods (NPL) and evaluating commercial micro-PMU vs. INRIM QPMU data.  

🛠️ Technical Contributions
Robust Signal Processing: Implemented FFT-based peak detection with adaptive thresholding (MAD-based) and sinusoidal least-squares validation.  
Aliasing Management: Integrated Nyquist-frequency handling for data at various reporting rates (10, 25, 50, 100 fps).  
Data Handling: Developed robust scripts for multi-format CSV/Excel parsing with automatic delimiter detection. 

📂 Repository Structuredocs/:
* [📄 Full Technical Report (PDF)](docs/technical_report_inrim.pdf) : Detailed study and results of the internship. 
scripts/: MATLAB implementation of detection algorithms and waveform generators.  
figures/: Key performance charts, including TVE comparisons and reporting-rate analysis. 
