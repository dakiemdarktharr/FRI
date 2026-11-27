const {contextBridge,ipcRenderer}=require('electron');
contextBridge.exposeInMainWorld('meetingPrompt',{answer:value=>ipcRenderer.send('meeting:prompt-answer',value),onData:callback=>ipcRenderer.on('meeting:prompt-data',(_e,data)=>callback(data))});
