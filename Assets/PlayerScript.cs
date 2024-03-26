using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.InputSystem;

public class PlayerScript : MonoBehaviour
{
    PlayerControls controls;
    public Vector2 move;
    public bool tryToJump;

    private void Awake()
    {
        controls = new PlayerControls();

        //Move Input
        controls.Gameplay.Move.performed += ctx => move = ctx.ReadValue<Vector2>();
        controls.Gameplay.Move.canceled += ctx => move = Vector2.zero;

        //Shoot Input
        controls.Gameplay.Jump.performed += ctx => tryToJump = true;
        controls.Gameplay.Jump.canceled += ctx => tryToJump = false;
    }
}
