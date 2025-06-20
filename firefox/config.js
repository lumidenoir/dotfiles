// ╔╗ ╔═╗╔╗╔╔╦╗╔═╗
// ╠╩╗║╣ ║║║ ║ ║ ║
// ╚═╝╚═╝╝╚╝ ╩ ╚═╝
// ┌─┐┌─┐┌┐┌┌─┐┬┌─┐┬ ┬┬─┐┌─┐┌┬┐┬┌─┐┌┐┌
// │  │ ││││├┤ ││ ┬│ │├┬┘├─┤ │ ││ ││││
// └─┘└─┘┘└┘└  ┴└─┘└─┘┴└─┴ ┴ ┴ ┴└─┘┘└┘

const CONFIG = {
	// ┌┐ ┌─┐┌─┐┬┌─┐┌─┐
	// ├┴┐├─┤└─┐││  └─┐
	// └─┘┴ ┴└─┘┴└─┘└─┘

	// General
	name: "Krishna",
	imageBackground: false,
	openInNewTab: true,
	twelveHourFormat: false,

	// Greetings
	greetingMorning: "Good morning!",
	greetingAfternoon: "Good afternoon,",
	greetingEvening: "Good evening,",
	greetingNight: "Go to Sleep!",

	// Layout
	bentoLayout: "lists", // 'bento', 'lists', 'buttons'

	// Weather
	weatherKey: "11c07c75b965a6e2f7246f507221e49d", // Write here your API Key
	weatherIcons: "OneDark", // 'Onedark', 'Nord', 'Dark', 'White'
	weatherUnit: "C", // 'F', 'C'
	language: "en", // More languages in https://openweathermap.org/current#multi

	trackLocation: true, // If false or an error occurs, the app will use the lat/lon below
	defaultLatitude: "37.775",
	defaultLongitude: "-122.419",

	// Autochange
	autoChangeTheme: true,

	// Autochange by OS
	changeThemeByOS: true,

	// Autochange by hour options (24hrs format, string must be in: hh:mm)
	changeThemeByHour: false,
	hourDarkThemeActive: "18:30",
	hourDarkThemeInactive: "07:00",

	// ┌┐ ┬ ┬┌┬┐┌┬┐┌─┐┌┐┌┌─┐
	// ├┴┐│ │ │  │ │ ││││└─┐
	// └─┘└─┘ ┴  ┴ └─┘┘└┘└─┘

	firstButtonsContainer: [
		{
			id: "1",
			name: "Github",
			icon: "github",
			link: "https://github.com/",
		},
		{
			id: "2",
			name: "Mail",
			icon: "mail",
			link: "https://nwm.iitk.ac.in/",
		},
		{
			id: "3",
			name: "Todoist",
			icon: "trello",
			link: "https://todoist.com",
		},
		{
			id: "4",
			name: "Calendar",
			icon: "calendar",
			link: "https://calendar.google.com/calendar/u/0/r",
		},
		{
			id: "5",
			name: "Reddit",
			icon: "glasses",
			link: "https://reddit.com",
		},
		{
			id: "6",
			name: "Odysee",
			icon: "youtube",
			link: "https://odysee.com/",
		},
	],

	secondButtonsContainer: [
		{
			id: "1",
			name: "Music",
			icon: "headphones",
			link: "https://open.spotify.com",
		},
		{
			id: "2",
			name: "twitter",
			icon: "twitter",
			link: "https://twitter.com/",
		},
		{
			id: "3",
			name: "bot",
			icon: "bot",
			link: "https://discord.com/app",
		},
		{
			id: "4",
			name: "Amazon",
			icon: "shopping-bag",
			link: "https://amazon.com/",
		},
		{
			id: "5",
			name: "Hashnode",
			icon: "pen-tool",
			link: "https://hashnode.com/",
		},
		{
			id: "6",
			name: "Figma",
			icon: "figma",
			link: "https://figma.com/",
		},
	],

	// ┬  ┬┌─┐┌┬┐┌─┐
	// │  │└─┐ │ └─┐
	// ┴─┘┴└─┘ ┴ └─┘

	// First Links Container
	firstlistsContainer: [
		{
			icon: "book",
			id: "1",
			links: [
				{
					name: "Matlab",
					link: "https://matlab.mathworks.com",
				},
				{
					name: "Hello IITK",
					link: "https://hello.iitk.ac.in",
				},
				{
					name: "Webmail",
					link: "https://nwm.iitk.ac.in",
				},
				{
					name: "Pingala",
					link: "https://pingala.iitk.ac.in",
				},
			],
		},
		{
			icon: "coffee",
			id: "2",
			links: [
				{
					name: "KeyBr", //TODO
					link: "https://www.keybr.com/",
				},
				{
					name: "Youtube",
					link: "https://www.youtube.com",
				},
				{
					name: "Dribble",
					link: "https://dribbble.com/",
				},
				{
					name: "Pocket",
					link: "https://www.pocket.com",
				},
			],
		},
	],

	// Second Links Container
	secondListsContainer: [
		{
			icon: "binary",
			id: "1",
			links: [
				{
					name: "My Repos",
					link: "https://github.com/lumidenoir",
				},
				{
					name: "DevDocs",
					link: "https://devdocs.io/",
				},
				{
					name: "Rust Docs",
					link: "https://www.rust-lang.org/learn",
				},
				{
					name: "WeChall",
					link: "https://www.wechall.net/",
				},
			],
		},
		{
			icon: "glasses",
			id: "2",
			links: [
				{
					name: "Unixporn",
					link: "https://www.reddit.com/r/unixporn/",
				},
				{
					name: "Rust",
					link: "https://www.reddit.com/r/rust/",
				},
				{
					name: "Go",
					link: "https://www.reddit.com/r/golang/",
				},
				{
					name: "Frontend",
					link: "https://www.reddit.com/r/Frontend/",
				},
			],
		},
	],
};
