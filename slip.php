<?php
// paths
$uploadDir = 'uploads/';
$wimFilePath = 'C:/path/to/your/install.wim'; 

// local0upload
if ($_SERVER['REQUEST_METHOD'] == 'POST' && isset($_FILES['applications'])) {
    $totalFiles = count($_FILES['applications']['name']);

    for ($i = 0; $i < $totalFiles; $i++) {
        $tmpFilePath = $_FILES['applications']['tmp_name'][$i];
        $fileName = basename($_FILES['applications']['name'][$i]);
        $targetFilePath = $uploadDir . $fileName;

        if (move_uploaded_file($tmpFilePath, $targetFilePath)) {
            echo "File uploaded: $fileName<br>";

            $mountPath = 'C:/mounted_image';
            $packageCmd = "dism /Mount-Wim /WimFile:$wimFilePath /index:1 /MountDir:$mountPath";
            $addAppCmd = "dism /image:$mountPath /Add-Package /PackagePath:$targetFilePath";
            $commitCmd = "dism /Unmount-Wim /MountDir:$mountPath /Commit";

            shell_exec($packageCmd);
            shell_exec($addAppCmd);
            shell_exec($commitCmd);

            echo "Added $fileName to the new Windows installation image.<br>";
        } else {
            echo "Nope. Failed to upload: $fileName<br>";
        }
    }
}
?>

<!DOCTYPE html>
<html>
<head>
    <title>Slipstream Applications into Windows Install</title>
</head>
<body>
    <h1>Upload Applications to Slipstream into Windows Install Image</h1>
    <form method="POST" enctype="multipart/form-data">
        <label for="applications">Select Applications (MSI/EXE) (Yes more than one.) to Add:</label><br>
        <input type="file" name="applications[]" id="applications" multiple><br><br>
        <input type="submit" value="Upload and Add to Image">
    </form>
</body>
</html>
