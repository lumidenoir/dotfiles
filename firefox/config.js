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
	imageBackground: true,
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
	//weatherKey: '11c07c75b965a6e2f7246f507221e49d', // Write here your API Key
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
			icon: "music",
			id: "1",
			links: [
				{
					name: "Ado",
					link: "https://music.youtube.com/playlist?list=RDCLAK5uy_nN_ul7B3hDoWnKJcp6474zHT7Y316oVg8",
				},
				{
					name: "Fuji Kaze",
					link: "https://music.youtube.com/playlist?list=RDCLAK5uy_kSRez2j51cPlJqX2cPs9E-q-3Ap9YA-pU",
				},
				{
					name: "Eve",
					link: "https://music.youtube.com/playlist?list=RDCLAK5uy_mVCo-luqdn6Gkdq0Cwe7RBgBCd6J5cKjs",
				},
				{
					name: "Yoasobi",
					link: "https://music.youtube.com/playlist?list=RDCLAK5uy_mHAEb33pqvgdtuxsemicZNu-5w6rLRweo",
				},
			],
		},
		{
			icon: "coffee",
			id: "2",
			links: [
				{
					name: "Linkedin", //TODO
					link: "https://www.linkedin.com",
				},
				{
					name: "Spotify", // TODO
					link: "https://www.spotify.com",
				},
				{
					name: "Dribble", //TODO
					link: "https://www.dribble.com",
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
					name: "Repos",
					link: "https://github.com/lumidenoir",
				},
				{
					name: "Reddit",
					link: "https://www.reddit.com",
				},
				{
					name: "Hashnode", // TODO
					link: "https://www.hashnode.com",
				},
				{
					name: "Pocket",
					link: "https://www.pocket.com",
				},
			],
		},
		{
			icon: "glasses",
			id: "2",
			links: [
				{
					name: "Frontend",
					link: "https://www.reddit.com/r/Frontend/",
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
					name: "Dribbble",
					link: "https://www.dribbble.com",
				},
			],
		},
	],
};
