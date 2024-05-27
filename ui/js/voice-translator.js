let finalTranscript = '';
let recognizing = false;
let ignoreOnend;
const twoLine = /\n\n/g;
const oneLine = /\n/g;
const firstChar = /\S/;
const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
const recognition = new SpeechRecognition();
const finalSpan = document.getElementById('final_span');
recognition.continuous = false;
recognition.interimResults = false;
// AWS configuration
let requestId;

let sourceLanguage = 'de';
let sourceDialect = 'AT';
let targetLanguage = 'en';

$(document).ready(() => {
  $('select').formSelect();
});

AWS.config.update({
  region: awsRegion,
  credentials: new AWS.CognitoIdentityCredentials({
    IdentityPoolId,
  }),
});
const s3 = new AWS.S3({
  apiVersion: '2006-03-01',
  params: { Bucket: bucketName },
  region: awsRegion,
});

// Get buttons from DOM
const recordStartButton = document.getElementById('start_button');
const recordStopButton = document.getElementById('stop_button');

// Add click event callbacks to buttons
recordStartButton.addEventListener('click', startRecording);
recordStopButton.addEventListener('click', stopRecording);

function babelStop() {
  document.getElementById('start_button').classList.remove('hide');
  document.getElementById('stop_button').classList.add('hide');
}

function babelStart() {
  document.getElementById('start_button').classList.add('hide');
  document.getElementById('stop_button').classList.remove('hide');
}

// Adjust buttons and message for processing
function processingView() {
  // Show processing message
  document.getElementById('processing').style.display = 'inline';
  // Disable all buttons
  recordStartButton.disabled = true;
  recordStopButton.disabled = true;
}

// Adjust buttons and message for recording
function recordingView() {
  // Hide processing message
  document.getElementById('processing').style.display = 'none';
  // Disable all buttons
  recordStartButton.disabled = true;
  recordStopButton.disabled = false;
}

// Reset buttons and hide messages
function resetView() {
  // Hide processing message
  document.getElementById('processing').style.display = 'none';
  // Disable all buttons
  babelStop();
  recordStartButton.disabled = false;
  recordStopButton.disabled = true;
}

// Record audio with device microphone
function startRecording() {
  // WebSpeech API
  finalTranscript = '';
  recognition.lang = `${sourceLanguage}-${sourceDialect}`;
  recognition.start();
  ignoreOnend = false;
  finalSpan.innerHTML = '';

  // // Adjust buttons and message for recording
  recordingView();
}

function stopRecording() {
  // Reset buttons and message

  resetView();
  if (recognizing) {
    recognition.stop();
  }
}

function sendTextToLambda() {
  processingView();
  const lambda = new AWS.Lambda({
    region: awsRegion,
    apiVersion: '2015-03-31',
  });

  const input = {
    FunctionName: lambdaFunction,
    InvocationType: 'RequestResponse',
    LogType: 'None',
    Payload: JSON.stringify({
      data: document.getElementById('results').innerText,
      sourceLanguage,
      targetLanguage,
      bucket: bucketName,
    }),
  };

  lambda.invoke(input, (err, data) => {
    if (err) {
      console.log(err);
      alert('There was a problem with Lambda function!!! ');
    } else {
      const resultUrl = data.Payload.replace(/['"]+/g, '');
      resetView();
      document.getElementById('audio-output').innerHTML = `<audio controls autoplay  style="display:inline"><source src="${
        resultUrl
      }" type="audio/mpeg"></audio><br/>`;
    }
  });
}

// Utility functions

function capitalize(s) {
  return s.replace(firstChar, (m) => m.toUpperCase());
}

function linebreak(s) {
  return s.replace(twoLine, '<p></p>').replace(oneLine, '<br>');
}

// WebSpeech API
recognition.onstart = function () {
  recognizing = true;
};

recognition.onerror = function (event) {
  if (event.error === 'no-speech') {
    ignoreOnend = true;
  }
  if (event.error === 'audio-capture') {
    ignoreOnend = true;
  }
  if (event.error === 'not-allowed') {
    ignoreOnend = true;
  }
};

recognition.onend = function () {
  recognizing = false;
  if (ignoreOnend) {
    return;
  }
  sendTextToLambda();
};

recognition.onresult = function (event) {
  if (typeof event.results === 'undefined') {
    recognition.onend = null;
    recognition.stop();
    return;
  }
  for (let i = event.resultIndex; i < event.results.length; i += 1) {
    finalTranscript += event.results[i][0].transcript;
  }
  finalTranscript = capitalize(finalTranscript);
  finalSpan.innerHTML = linebreak(finalTranscript);
};

$(document).on('change', 'select', function () {
  const selectedValue = $(this).val();
  const [mode, language, dialect] = selectedValue.split('-');
  if (mode === 'source') {
    sourceLanguage = language;
    sourceDialect = dialect;
  } else {
    targetLanguage = language;
  }
});
