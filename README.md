# pension-inequalities
Repository for summer student work on inequalities in pension saving

## Project background and motivation

The UK government has introduced various pension reforms over the past decade, which have reduced the generosity of the public pension system and encouraged greater private saving. This means that in the future pension incomes will increasingly be driven by individuals’ choices about how much to save and the return that these savings achieve. 

This project would use Understanding Society (USoc), which has rich information on both individual circumstances and pension saving, to measure inequalities in pension saving decisions. This would build on recent work I did with Rowena looking at differences in pension saving rates by gender and age. In addition, there are many other dimensions that could be studied in USoc, including: ethnicity, education, region, and health/disability. We should also check if there are any other variables in USoc that could be interesting. If time allows, we could then look at the effect of automatic enrolment on both pension membership and the distribution of contribution rates, as well as its effect on pension saving inequalities. 

Related readings include: 
- [Lifecycle patterns in pension saving - IFS report 2021](https://ifs.org.uk/publications/15425)
- [Saving for retirement in Great Britain: April 2018 to March 2020 - ONS report 2022](https://www.ons.gov.uk/peoplepopulationandcommunity/personalandhouseholdfinances/incomeandwealth/bulletins/pensionwealthingreatbritain/april2018tomarch2020#building-pension-wealth-over-a-lifetime)
- [Understanding the gender pension gap - IFS observation 2021](https://ifs.org.uk/publications/15425)
- Draft IFS report - when and why do employees change their pension saving? (See project folder)

## Understanding Society

Understanding Society is a longitudinal survey of around 40,000 UK households. Questions on workplace pension saving is asked in every even wave (i.e. every other year). It also has detailed information on other individual and household characteristics, allowing us to look at inequalities we can't observe in other surveys (e.g. Annual Survey of Hours and Earnings, Self Assessment data). 

The [Understanding Society website](https://www.understandingsociety.ac.uk/) is actually quite helpful. In particular, if you want to find out more about what kind of data is in the survey, [this page](https://www.understandingsociety.ac.uk/documentation/mainstage/dataset-documentation/questionnaire-modules) shows you all the questionnaire modules asked in each wave. If you want information about a particular variable, you can use the [variable search](https://www.understandingsociety.ac.uk/documentation/mainstage/dataset-documentation) page. 

To clean the raw data files, I have used the so-called "USoc extractor". This is basically a bunch of (over-complicated) Stata ado files originally written by a former IFS employee approximately ten years ago, and updated since primarily by Peter Levell. After a lot of time spent staring at code and scratching my head, I have a vague understanding of how it works but am by no means an expert. If you want any more variables from USoc, just ask me and I can get them - there's no point you wasting ages trying to get your head round the extractor. 

## Github workflow

To organise the project, I would like to try using Git and Github. One caveat straight up is that I have only limited experience with this sort of thing, and it is not widely used at the IFS either. So, a lot of this will be new for the both of us, and we will probably have a few teething problems at some point. But, I think this will be a useful as (i) it should allow me to give you more detailed comments on your code, meaning you can improve faster, (ii) at the end we will have a detailed log of the project, which I can come back to in the future, and (iii) this sort of workflow is a good thing for you to learn in general, as its use in economic research is increasing and it is also used in many other industries too. 

This sort of workflow is based on that used by two Stanford economics professors, Matthew Gentzkow and Jesse Shapiro. They wrote an article [here](https://web.stanford.edu/~gentzkow/research/CodeAndData.pdf) describing the thinking behind it - I would highly recommend reading it. They have also very kindly put the manual for their RAs online - see [here](https://github.com/gslab-econ/ra-manual/wiki/Introduction). 

The basic idea is that we'll use the Git version control system to organize our code and data. And we'll use issues on Github to manage tasks and structure communication around projects.

### 1. Getting up to speed with git 

Git is an open-source version control system and is used in the vast majority of sofware projects out there today. It is also becoming more commonly used in research projects, allowing you to keep a track of the history of your project over time in a clean and organised way, as well as to sort out problems when multiple researchers are working on the same file at once. 

To learn the principles behind git, I would recommend watching an IFS Tech presentation that Max gave a few weeks ago - see the useful_resources folder for a link. The [Git handbook](https://docs.github.com/en/get-started/using-git/about-git) is another great resource.

### 2. Getting up to speed with Github and the Github Flow workflow

We'll store the repository of our code on Github, and will use it to structure the tasks and communication around the project. Specifically, we'll use the Github Flow workflow. Here are some resources for understanding this:

- [Understanding the GitHub Flow](https://guides.github.com/introduction/flow/)
- [Mastering Issues](https://guides.github.com/features/issues/)
- [Mastering Markdown](https://guides.github.com/features/mastering-markdown/)

The Gentzkow and Shapiro RA manual describes the workflow [here](https://github.com/gslab-econ/ra-manual/wiki/Workflow).

Basically, the workflow will be as follows:

1. Someone (usually Laurence) will create an issue on Github, describing a task/set of tasks to complete. The branch will usually be assigned to Jack.
2. The assignee will make a branch corresponding to that issue on Github. Basically, under "Development", click on **Create a branch**. Select the option "Checkout locally". [More detailed instructions](https://docs.github.com/en/issues/tracking-your-work-with-issues/creating-a-branch-for-an-issue)
3. The assignee will then checkout the branch locally. I would recommend using the command line for this. First, navigate to the local project folder (use the `cd` command). Then, use the commands `git fetch origin` and `git checkout branch-name`.
4. Then, the assignee can work on the issue on their local machine. They should make regular commits to create a snapshot of the code when they've made some progress. Every commit should have a commit message of the form `#X Description of commit`, where `X` is the Github issue number (e.g. "#123 Make graph of pension membership by ethnicity"). Use the command line to make a commit. Once in the project folder, you first you need to specify which files in the folder to commit (aka stage) using `git add`. `git add -A` will add all changed files in the folder to the commit. Then, the command to commit the staged files is `git commit -m "Commit message here"`. You can also "push" your commits to the branch. It's slightly up to you how regularly you want to do this, but at the very least you need to do it before moving on to step 5 (i.e. once you think working on the issue is complete). Use the command `git push` for this (after adding and committing). While working on an issue, any notes from in-person meetings should be added as comments to the issue on Github.
5. When work on an issue is complete (and you've committed and pushed it all), the assignee should make a pull request. Do this on Github by selecting the issue branch on the `code` tab of the repository's Github page then clicking `New Pull Request`. The title of the pull request should be `PR for #X: original_issue_title`, where `X` is the Github issue number. The description of the pull request should begin with a line that says `Closes #X`, where `X` is the Github issue number. This will close the original Github issue and create a link in that issue to the pull request. Subsequent lines of the description can be used to provide instructions (if any) to the peer reviewer. The pull request should be assigned to the assignee of the original issue.
6. The original assignee (usually Laurence) will then peer review the code. All peer review comments should be made on the pull request itself, not on the original issue. Revision to the code and other files in the repository as part of the peer review process shall be made in the original issue branch (issueXXX_description). The pull request will automatically track changes made in the branch. 
7. When peer review is complete, the issue branch should be merged back to `master` using a squash merge. You can do this from the pull request page on Github. Then you can delete the issue branch, both on Github, and locally. To delete it locally, use the command `git branch -d <branch-name>`.

