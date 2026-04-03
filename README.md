This script calculates the evolution of the CaCO3 ion activity product
and reports {Ca}, {CO3}, [Ca], [Mg], and [DIC] during a CaCO3
precipitation experiments in which a (Mg,Ca)Cl2 and or Na2CO3 solution 
is titrated at a constant rate into a solution of known initial
composition.

If this is useful to your research, please cite Arns et al. (2026) 
Probing salty waters: re-assessment of the early stages of calcium 
carbonate formation in seawater. Geochimica et Cosmochimica Acta.
https://doi.org/10.1016/j.gca.2026.03.048

Please forward suggestions and comments on this script to David Evans
(d.evans@soton.ac.uk)

To function, the following are required:
  - data from a calibrated pH electrode and Ca ISE voltage
  - a Ca-ISE calibration in a separate data file, in which CaCl2 was
  added into a solution of known initial composition in several steps
  - a metadata file containing information regarding the solution
  compositions, titration timing and rate

The script is designed to work with Metrohm csv files written by Tiamo
2.5 or later. An example Tiamo method file that should produce output
compatible with this software is provided in the repository.

Data processing is performed three times, detailed in Arns et al. (2026):
1. Assuming no precipitation or ion association takes place, beyond that
  which can be explained by the pitzer_SW25.dat parameters.
2. Assuming the entirety of the difference between the measured {Ca} and
  that calculated as per #1 is due to CaCO3 precipitation. In this case
  the [Ca] is iteratively solved to bring the calculation and measurement
  into agreement, and the [DIC} is reduced by an equivalent amount. This
  is the prefered method in Arns et al. (2026).
3. Assuming that NaOH counter titration (in the event that pH was
  maintained at a constant value) is related to DIC via the reaction 
  Ca2+ + HCO3- = CaCO3 + H+

The first part of the script calculates the relationship between Ca ISE
voltage and {Ca2+} using the calibration data file. The second part
applies this and the pH data to fully solve the relevant details of
solution chemistry during the titration experiment. Multiple data files
can be processed in turn by adding further rows to the metadata csv file.

Known dependancies:
- parallel computing (or replace parfor with for below), statistics,
curve fitting toolboxes
- a phreeqc COM installation and a copy of the pitzer_SW25.dat database
file (included in the repository)
- CO2SYSpalaeo.m, a modified version of the Matlab version of CO2SYS to
include the impact of [Ca], [Mg], and [SO4] on the C system dissociation
constants
