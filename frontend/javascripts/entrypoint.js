import { dom, library } from '@fortawesome/fontawesome-svg-core';
import { faCheckCircle, faSpinner, faExclamationTriangle } from '@fortawesome/free-solid-svg-icons';
import { faGithub } from '@fortawesome/free-brands-svg-icons';

library.add(faCheckCircle, faSpinner, faExclamationTriangle);
library.add(faGithub);
dom.watch();

import '../stylesheets/entrypoint.scss';
