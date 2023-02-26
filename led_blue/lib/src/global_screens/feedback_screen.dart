import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/container.dart';
import 'package:flutter/src/widgets/framework.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  TextEditingController emailController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feedback'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
          reverse: true,
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Center(
                child: Text(
                  "Bitte fühlen Sie die Problembeschreibung aus, damit wir Ihnen besser helfen können.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),
              ),
              SizedBox(
                height: 30,
                width: 200,
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextFormField(
                  onTap: () {},
                  controller: emailController, // Controller for Username
                  decoration: InputDecoration(
                      border: InputBorder.none,
                      fillColor: Colors.white,
                      hintText: "Kontakt",
                      contentPadding: EdgeInsets.all(20)),
                  onEditingComplete: () => FocusScope.of(context).nextFocus(),
                ),
              ),
              SizedBox(
                height: 30,
                width: 10,
              ),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextFormField(
                  onTap: () {},
                  controller: emailController, // Controller for Username
                  decoration: InputDecoration(
                      border: InputBorder.none,
                      fillColor: Colors.white,
                      hintText: "Kontakt",
                      contentPadding: EdgeInsets.all(20)),
                  onEditingComplete: () => FocusScope.of(context).nextFocus(),
                ),
              ),
              SizedBox(
                height: 30,
                width: 10,
              ),
              InkWell(
                onTap: () {},
                child: DottedBorder(
                  borderType: BorderType.RRect,
                  radius: Radius.circular(5),
                  dashPattern: [10, 10],
                  color: Colors.white,
                  strokeWidth: 3,
                  child: Container(
                      padding: EdgeInsets.only(top: 20),
                      width: double.infinity,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Image.asset(
                            "assets/images/add_image_icon.png",
                            width: 50,
                            height: 50,
                          ),
                          SizedBox(height: 10),
                          Text("Bild hochladen"),
                          SizedBox(height: 20),
                        ],
                      )),
                ),
              ),
              Container(
                width: 570,
                height: 70,
                padding: EdgeInsets.only(top: 20),
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          backgroundColor: Colors.orange,
                          color: Colors.black,
                          strokeWidth: 8,
                        ),
                      )
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          primary: Color.fromRGBO(58, 174, 159, 1),
                        ),
                        child: Text("Absenden",
                            style: TextStyle(color: Colors.white)),
                        onPressed: () async {
                          setState(() {
                            _isLoading = true;
                          });
                        }),
              ),
            ],
          )),
    );
  }
}
