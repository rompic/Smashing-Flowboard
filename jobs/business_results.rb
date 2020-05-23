# frozen_string_literal: true

# Change this job to obtain data from an external source.
SCHEDULER.every '30m', first_in: 0 do
  items = []
  items.push(title: 'Value', subelements: [{ label: 'TBD', value: 'TBD' }])
  items.push(title: 'Cost', subelements: [{ label: 'Cost on EXACC', value: 'TBD €' }])
  items.push(title: 'Quality', subelements: [{ label: 'Escaped Defects', value: 'TBD' }])
  items.push(title: 'Happiness', subelements: [{ label: 'eNPS (-100 / +100)', value: 'TBD' }, { label: 'Culture', value: 'TBD/7' }])
  send_event('business_results', items: items)
end
