

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:upstyle/main.dart';

class Shared {
	BuildContext context;

	SharedPreferences prefs;

	MyAppState myAppState;
	MyHomePageState myHomePageState;

	FirebaseUser user;
	String token;
	UserInfo userInfo;
	bool isLoggedIn = false;

	FirebaseAuth _auth = FirebaseAuth.instance;
	GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

	GraphQL graphQL = GraphQL();


	Shared() {
		onStartup();
	}


	login() async {
		print('doing login');


		if ( (user = await _auth.currentUser()) == null || userInfo == null ) {
			GoogleSignInAccount googleUser = await _googleSignIn.signIn();
			GoogleSignInAuthentication googleAuth =
				await googleUser.authentication;
			AuthCredential credential = GoogleAuthProvider.getCredential(
				idToken: googleAuth.idToken,
				accessToken: googleAuth.accessToken,
			);
			AuthResult authResult =
				(await _auth.signInWithCredential(credential));
			user = authResult.user;
			print(authResult.additionalUserInfo.profile);

			userInfo = UserInfo.fromJson(
				authResult.additionalUserInfo.profile
			);
			userInfo.uid = user.uid;
			prefs.setString('userInfo.name', userInfo.name);
			prefs.setString('userInfo.surname', userInfo.surname);
			prefs.setString('userInfo.locale', userInfo.locale);



		}
		print('successful login of ${userInfo.fullName}');
		await refreshHasuraToken();
		isLoggedIn = true;
		myAppState.setState(() {

		});
	}

	logout() {
		print('doing logout of ${userInfo.fullName}');

		_googleSignIn.signOut();
		_auth.signOut();

		print(_auth.currentUser());
		isLoggedIn = false;
		myAppState.setState(() {

		});
	}

	onStartup() async {
		user = await _auth.currentUser();
		prefs = await SharedPreferences.getInstance();
		if (user != null) {
			userInfo = UserInfo(
				uid: user.uid,
				email: user.email,
				isEmailVerified: user.isEmailVerified,
				fullName: user.displayName,
				profilePicURL: user.photoUrl,
				name: prefs.get('userInfo.name'),
				surname: prefs.get('userInfo.surname'),
				locale: prefs.get('userInfo.locale'),
			);
			await refreshHasuraToken();
			isLoggedIn = true;
			myAppState.setState(() {

			});
		}
	}

	refreshHasuraToken() async {
		IdTokenResult idTokenResult = await user.getIdToken();
		token = idTokenResult.token;
		graphQL.withToken(token);
		print(idTokenResult.claims);
		Map<String, dynamic> hasuraClaim = idTokenResult
			.claims['https://hasura.io/jwt/claims'] ?? null;
		if (hasuraClaim != null) {
			return;
		}
		else {
			// Check if refresh is required
			DatabaseReference metadataRef = FirebaseDatabase.instance.reference()
				.child('metadata')
				.child(user.uid)
				.child('refreshTime');
			metadataRef.onValue.listen((Event event) {
				print('token refresh: ${event.snapshot.value}');
				user.getIdToken(refresh: true);
			});

		}
	}
}


class UserInfo {
	String uid;
	String email;
	bool isEmailVerified;
	String fullName;
	String profilePicURL;
	String name;
	String surname;
	String locale;

	UserInfo({this.uid, this.email, this.isEmailVerified, this.fullName,
		this.profilePicURL, this.name, this.surname, this.locale});


	factory UserInfo.fromJson(Map<String, dynamic> json) =>
		UserInfo(
			email: json['email'],
			isEmailVerified: json['email_verified'],
			fullName: json['name'],
			profilePicURL: json['picture'],
			name: json['given_name'],
			surname: json['family_name'],
		)
	;

	Map<String, dynamic> toJson() =>
		{
			'uid': uid,
			'email': email,
			'isEmailVerified': isEmailVerified,
			'fullName': fullName,
			'profilePicURL': profilePicURL,
			'name': name,
			'surname': surname,
			'locale': locale,
		}
	;


}

class GraphQL {
	HttpLink httpLink = HttpLink(
		uri: 'https://hasura-up-style.herokuapp.com/v1/graphql',
	);

	AuthLink authLink;
	Link link;
	ValueNotifier<GraphQLClient> client;

	GraphQL() {
		link = httpLink;

		client = ValueNotifier(
			GraphQLClient(
				cache: InMemoryCache(),
				link: link,
			),
		);
	}

	withToken(String token) {
		authLink = AuthLink(
			getToken: () => 'Bearer $token'
		);
		link = authLink.concat(httpLink);
	}
}