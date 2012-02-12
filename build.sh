#!/bin/sh

#
# TO CONFIGURE
#
# Xcode Targets
APP_TARGET=Bobbins
UNIT_TEST_TARGET=BobbinsTest

#provisioning keys & certificates
PROVISIONING_PATH=$CURRENT_PATH/provisioning

#... could iterate, but I'm lazy.
PROVISIONING_KEY1=$PROVISIONING_PATH/DistributionKey.p12
PROVISIONING_KEY2=$PROVISIONING_PATH/DistributionKey.p12
MOBILE_PROVISIONING=$PROVISIONING_PATH/CompanyName.mobileprovision
MOBILE_PROVISIONING_DESCRIPTION="iPhone Distribution: Bobbins Inc"
KEY_PASSWORD=password

#keychain config
KEYCHAIN_PASSWORD=password

#
# NORMAL STUFF
#
CURRENT_USER=`whoami`
CURRENT_PATH=`pwd`


function createKeychain() {
    security create-keychain -p $KEYCHAIN_PASSWORD xcodebuild.keychain
    security add-certificates -k xcodebuild.keychain $PROVISIONING_PATH/AppleWWDRCA.cer $PROVISIONING_PATH/developer_identity.cer $PROVISIONING_PATH/distribution_identity.cer
    security unlock-keychain -p $KEYCHAIN_PASSWORD xcodebuild.keychain
    security import $PROVISIONING_KEY1 -P $KEY_PASSWORD -k xcodebuild.keychain -T /usr/bin/codesign
    security import $PROVISIONING_KEY2 -P $KEY_PASSWORD -k xcodebuild.keychain -T /usr/bin/codesign
    security default-keychain -s xcodebuild.keychain
}

function deleteKeychain() {
    security delete-keychain xcodebuild.keychain
    security default-keychain -s login.keychain
}

function cleanTargets() {
    rm -rf ~/Library/Developer/Xcode/DerivedData
    rm -rf ~/Library/Application Support/iPhone Simulator
    xcodebuild -target $APP_TARGET -sdk iphoneos -configuration Release clean;
    xcodebuild -target $APP_TARGET -sdk iphoneos -configuration Debug clean;
    xcodebuild -target $UNIT_TEST_TARGET -sdk /Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator5.0.sdk/ -configuration Debug clean;
}

function runTests() {
    createKeychain;
    #uncomment the end if you want to use ocunit2junit to produce test results.
    xcodebuild -verbose -target $UNIT_TEST_TARGET -sdk /Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator5.0.sdk/ -configuration Debug build #| ./ocunit2junit.rb
    OUT=$?
    deleteKeychain;
    if [ $OUT -ne 0 ]
    then
        echo "Build FAILED : $OUT";
        exit 1
    fi
}

function releaseAllConfigurations() {
  createKeychain;
  rm -rf $CURRENT_PATH/archives;
  mkdir -p $CURRENT_PATH/archives;
  buildIPA Development;
  buildIPA Release;
  deleteKeychain;
}

function buildIPA() {
  CONFIGURATION=$1
  xcodebuild -target $APP_TARGET -sdk iphoneos -configuration $CONFIGURATION build;
  xcrun -sdk iphoneos PackageApplication -v $CURRENT_PATH/build/$CONFIGURATION-iphoneos/$APP_TARGET.app -o $CURRENT_PATH/build/$APP_TARGET-$CONFIGURATION.ipa -sign $MOBILE_PROVISIONING_DESCRIPTION -embed $MOBILE_PROVISIONING;
}

case "$1" in
  clean)
  cleanTargets;;

  test)
  runTests;;

  release)
  releaseAllConfigurations;;
  *)
  echo "Usage: build.sh (clean|test|release) e.g. ./build.sh test";
  exit 1;;
esac

exit 0
