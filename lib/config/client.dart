import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:upstyle/shared.dart';

class Config {
	Shared shared;
	HttpLink httpLink = HttpLink(
		uri: 'https://hasura-up-style.herokuapp.com/v1/graphql'
	);

	AuthLink authLink = AuthLink(
		getToken: () async => ''
	);


}