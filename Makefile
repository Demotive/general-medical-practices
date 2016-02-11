UNAMENDED_CSV=$(shell find input/ -name 'epraccur_*.csv')
AMENDMENT_CSVS=$(shell find input/monthly_amendments -name 'egpam_*.csv')
AMENDMENT_PRACTICE_CSV=build/combined-amendments-only-gp-practices.csv

FINAL_JSON=output/general-medical-practices.json

.PHONY: all
all: $(FINAL_JSON)

$(AMENDMENT_PRACTICE_CSV): $(AMENDMENT_CSVS)
	cat $(AMENDMENT_CSVS) | grep -v -e '^"G[0-9]\{7\}' > $(AMENDMENT_PRACTICE_CSV)

.PHONY: $(FINAL_JSON)
$(FINAL_JSON): $(UNAMENDED_CSV) $(AMENDMENT_PRACTICE_CSV)
	./process/convert.rb $(UNAMENDED_CSV) $(AMENDMENT_PRACTICE_CSV) > $(FINAL_JSON)
