# Code Embed LTI Tool
- live at [code-embed-lti.herokuapp.com](https://code-embed-lti.herokuapp.com)!
- instructions for installation and usage [here](https://code-embed-lti.herokuapp.com)
- featured on [Edu Apps](https://www.edu-apps.org/index.html?tool=code_embed)
- placed in the top ten for the [LTI App Bounty](http://instructure.github.io/lti_bounty) initiated by Instructure

Code Embed allows instructors to embed a code editor in their LMS (Canvas, Blackboard, Desire2Learn, etc).  I hope to be able to spend more time on it and add some cool features like the ability to create coding assessments, do code execution and show output, auto-grade assessments, etc.  Contributions and ideas are always welcome!

## Shout outs
Code Embed
- was developed as part of an [LTI App Bounty](http://instructure.github.io/lti_bounty) initiated by Instructure
- started out as a [lti_tool_provider_example](https://github.com/instructure/lti_tool_provider_example) (thanks Instructure for making it so easy to get started!)
- built on the [Ace](https://github.com/ajaxorg/ace) code editor
- uses the [ims-lti](https://github.com/instructure/ims-lti) gem for authenticating LTI consumers

## Development
To get this running in your development environment, check out the repo, then run:

    bundle install
    shotgun

You can use the XML from the `/tool_config.xml` endpoint to configure the tool in a Tool Consumer.
