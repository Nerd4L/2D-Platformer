using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.U2D;

public class CamerScript : MonoBehaviour
{
    public PixelPerfectCamera pixelPerfectCamera;

    // Start is called before the first frame update
    void Start()
    {
        //pixelPerfectCamera = new PixelPerfectCamera();
        //Debug.Log(pixelPerfectCamera);
        //pixelPerfectCamera.gameObject.SetActive(true);
        gameObject.GetComponent<PixelPerfectCamera>().enabled = true;
    }

    // Update is called once per frame
    void Update()
    {
        
    }
}
