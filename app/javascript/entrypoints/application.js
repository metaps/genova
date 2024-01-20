import 'bulma/css/bulma.min.css'
import 'bulma-timeline/dist/css/bulma-timeline.min.css'
import '@fortawesome/fontawesome-free/js/all'
import './application.scss'
import 'bulma-calendar/dist/css/bulma-calendar.min.css';
import bulmaCalendar from 'bulma-calendar/dist/js/bulma-calendar.min.js';

const urlParams = new URLSearchParams(window.location.search);
const datesParams = urlParams.get('dates');

let startDate = null;
let endDate = null;

if (datesParams) {
  const dates = datesParams.split('-');

  startDate = dates[0] && !isNaN(Date.parse(dates[0])) ? new Date(dates[0]) : null;
  endDate = dates[1] && !isNaN(Date.parse(dates[1])) ? new Date(dates[1]) : null;

  if (startDate && endDate && startDate > endDate || (startDate == null || endDate == null)) {
    startDate = null;
    endDate = null;
  }
}

const options = {
  isRange: true,
  lang: 'en',
  dateFormat: 'yyyy/MM/dd',
  startDate: startDate,
  endDate: endDate,
};

const calendars = bulmaCalendar.attach('[name="dates"]', options);
