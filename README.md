PingCastle Diff
===

PingCastle Diff is a PS1 that will highlight the rule diff between two PingCastle scans and send the result into a Teams/Element room channel or a log file. It is a simplified version of the great [PingCastle-Notify](https://github.com/LuccaSA/PingCastle-Notify). I simplified the code and added the Element integration since my usage of PingCastle doesn't match with the one of PingCastle-Notify, I run PingCastle as it is and then I do the comparison with previous scans later, if I need to, and I wanted to have challenge myself to edit a pretty long PowerShell script which I've never done before.

This is the operation flow of PingCastle-Diff. 
1. Copy scans into your ps1 folder
2. Execute diff between scans
3. Send notification to scan.log // Element chat // Teams channel (I removed the Slack support from PingCastle-Notify since I haven't had the possibility to test it and my environment is composed by Teams and/or Element teams/chats. )

<p align="center">

> :warning: If you don't want to use Teams or Element set the variable `$teams` or `$element` to 0 inside the ps1 script (1 means they're active). Skip the step "Create a BOT" and check the log file inside the root folder.

</p>
<hr>
<details>
<summary>:arrow_forward: <b>First scan</b></summary>

Image from PingCastle-Notify. The difference from Element is just how they emojis are rendered.

| Teams
|:-------------------------:
|   ![image](https://user-images.githubusercontent.com/5891788/193760283-ef171f2d-6992-44b7-ad8e-8b3f113ffe3d.png)


</details>
<details>
<summary>:arrow_forward: <b>No new vulnerability but some rules have been updated</b></summary>

Image from PingCastle-Notify. The difference from Element is just how they emojis are rendered.

![image](https://user-images.githubusercontent.com/5891788/191266282-cd790c58-76df-4116-89fa-4aa954f0dd7e.png)

</details>
<details>

<summary>:arrow_forward: <b>New vulnerabilty</b></summary>

Image from PingCastle-Notify. The difference from Element is just how they emojis are rendered.

| Teams
|:-------------------------:
|   ![image](https://user-images.githubusercontent.com/5891788/193760136-668fca48-9ddf-47dd-b82a-0708117954f1.png)


</details>
<details>
<summary>:arrow_forward: <b>Some vulnerability have been removed</b></summary>

Image from PingCastle-Notify. The difference from Element is just how they emojis are rendered.

Teams|
|:-------------------------:
|   ![image](https://user-images.githubusercontent.com/5891788/193760223-8658c35c-0ef3-4012-8679-8946987f4e4a.png)
 


</details>
<details>
<summary>:arrow_forward: <b>No new vulnerability</b></summary>

No result since reports are the same
</details>

---
<details>
<summary>:beginner: <b>Adding the result of the current scan</b></summary>

Set the variable `$print_current_result` to 1 in the script, the rules flagged on the current scan will be added after the rule diff on Teams and on Element.

Image from PingCastle-Notify. The difference from Element is just how they emojis are rendered.

| Teams
|:-------------------------:
|   ![Teams_8N2r3YiVh4](https://user-images.githubusercontent.com/5891788/194527837-8f6f0910-aa17-47d2-bfee-01d4defa569b.png)
</details>



## How to run ?

### Structure of the project

```
your-directory/
    - PingCastle-Diff.ps1
    - new_report.xml
    - new_report.html
    - old_report.xml
    - old_report.html
    - ...
```

where `new_report.xml|html` is the name of your latest PingCastle scan and `old_report.xml|html` is the name of the first(old) PingCastle scan.

#### Create a BOT
<details>
<summary>:arrow_forward: <b>Teams BOT</b></summary>

1. Follow this [guide](https://learn.microsoft.com/en-us/microsoftteams/platform/webhooks-and-connectors/how-to/add-incoming-webhook?tabs=newteams%2Cdotnet)
2. Update the ps1 script accordingly
</details>

<details>
<summary>:arrow_forward: <b>Element BOT</b></summary>

1. Follow this [guide](https://github.com/jkhsjdhjs/maubot-webhook)
2. Update the ps1 script accordingly
3. I have used this template:
```
path: /send
method: POST
room: '...'
message: |
    {{ json.msg }}
message_format: markdown
auth_type: Basic
auth_token: username:password
force_json: false
ignore_empty_messages: false
```
</details>

#### Execution Parameters

PingCastle-Diff requires mandatory two string input parameters `new_name` which is the name (just the name, not the extension) of your latest PingCastle scan (`new_report` in out example directory structure) and `old_name` which is the name (just the name, not the extension) of the first(old) PingCastle scan (`old_report` in out example directory structure).

Example run:

`.\PingCastle-Diff.ps1 -new_name "new_report" -old_name "old_report"`


## Acknowledgements for PingCastle-Notify (original project)

- Vincent Le Toux - https://twitter.com/mysmartlogon
- Romain Tiennot - https://github.com/aikiox
- Lilian Arago - https://github.com/NahisWayard
- Romain Bourgue - https://github.com/raomin

## License

MIT License
